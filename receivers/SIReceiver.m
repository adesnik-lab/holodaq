classdef SIReceiver < Receiver
    %SIRECEIVER Persistent ScanImage primer. Run once on the SI computer via
    %   start_si_listener. On each new experiment prime it sets the save
    %   filename to match the DAQ's Saver stem, enables logging + external
    %   trigger, enables the experiment's user function, and arms acquisition
    %   (startLoop) so ScanImage waits for the DAQ trigger. Requires hSI/hSICtl
    %   in the base workspace.
    %
    %   Priming is meant to be NEUTRAL about what the user set up by hand: it
    %   captures and restores "Enable Stack" and the imaging beam power (the %
    %   in Power Controls) around everything it does. See getBeamPowers.

    properties
        hSI
        hSICtl
        si_root = 'D:'   % local drive/base for ScanImage tiff logging on the SI PC
        acq_drift = ''   % first prime step seen to move the acquisition counts, '' if none
    end

    properties (Constant)
        % The operator's acquisition counts, guarded as a set because ScanImage
        % couples them: numVolumes is derived from enable/stackMode, and numSlices
        % is what ties it to framesPerSlice. Capturing all three makes a drift
        % report interpretable even though only two have GUI boxes.
        ACQ_COUNT_PROPS = {'framesPerSlice', 'numVolumes', 'numSlices'}
    end

    methods
        function obj = SIReceiver(si_root)
            obj = obj@Receiver('si');
            if nargin >= 1 && ~isempty(si_root)
                obj.si_root = si_root;
                src = 'the start_si_listener argument';
            else
                % Was rig_get, which reads the rig loaded THIS session -- and
                % nothing on the SI computer ever calls load_rig, so it always
                % returned the 'D:' class default no matter what the rig file
                % said. rig_remote_get reads the config the DAQ published, then a
                % local rig file, then the default.
                [obj.si_root, src] = rig_remote_get('paths.si_root', obj.si_root);
            end
            fprintf('SIReceiver: ScanImage tiff root ''%s'' (from %s).\n', ...
                obj.si_root, src);
        end

        function run(obj)
            mouse = obj.config.mouse;
            epoch = obj.config.epoch;
            expt  = obj.config.experiment;
            stamp = obj.date_stamp();

            obj.hSI    = evalin('base', 'hSI');
            obj.hSICtl = evalin('base', 'hSICtl');

            % Priming must not change the user's Stack setting; capture it now
            % and restore it before arming (something in the prime/abort path
            % was clearing "Enable Stack").
            stackEnable = obj.getStackEnable();

            % Same deal for the imaging beam power (the % in Power Controls):
            % the power the user dialed in before launching is the power the
            % experiment runs at. Nothing in holodaq/holoexpt writes hBeams, so
            % whatever moves it is ScanImage reacting to one of the calls below
            % -- abort, updateView, the user-function swap, the Stack restore,
            % or startLoop. Snapshot before all of them, put it back after.
            beamPowers = obj.getBeamPowers();

            % And the same for the acquisition counts -- the # Frames / # Volumes
            % the operator typed into ScanImage's Main Controls. Nothing in any of
            % these repos writes them, so they are purely the operator's, yet they
            % were coming back as the PREVIOUS grab's values: something in the
            % sequence below re-derives the stack geometry. Captured before
            % anything runs; obj.acq_drift below then names the first call that
            % moves them, since which one it is cannot be settled off the rig.
            acqCounts = obj.getAcqCounts();
            obj.acq_drift = '';

            % Stop any prior looped acquisition before re-arming for a new expt.
            try, obj.hSI.abort(); catch, end
            obj.noteAcqDrift(acqCounts, 'abort');

            obj.hSI.extTrigEnable            = 1;
            obj.hSI.hChannels.loggingEnable  = 1;

            % ScanImage does NOT create the log directory and throws "Invalid
            % file identifier" when it can't open the tiff in a missing folder,
            % so build the path with native (Windows) separators via fullfile
            % and create it first. Base drive is obj.si_root (default 'D:').
            logdir = fullfile(obj.si_root, stamp, mouse, sprintf('%d%s', epoch, expt));
            if ~isfolder(logdir)
                [ok, msg] = mkdir(logdir);
                if ~ok
                    error('SIReceiver: could not create log dir "%s": %s', logdir, msg);
                end
            end
            % logFileStem MUST match the DAQ Saver stem <date>_<mouse>_<epoch><expt>
            % so OnlineSession can pair the tiffs with the K: stim-data file.
            obj.hSI.hScan2D.logFilePath    = logdir;
            obj.hSI.hScan2D.logFileStem    = sprintf('%s_%s_%d%s', stamp, mouse, epoch, expt);
            obj.hSICtl.updateView();
            obj.noteAcqDrift(acqCounts, 'updateView');

            obj.set_user_function();
            obj.noteAcqDrift(acqCounts, 'set_user_function');

            % Force the acquisition number back to 1 right before arming, so
            % stray trailing files don't auto-bump it to a higher number — we
            % want to overwrite from _00001. (Set last so nothing re-derives it.)
            obj.hSI.hScan2D.logFileCounter = 1;
            obj.restoreStackEnable(stackEnable);   % keep the user's Stack setting
            obj.noteAcqDrift(acqCounts, 'restoreStackEnable');
            obj.restoreBeamPowers(beamPowers, 'prime');   % keep the user's power

            % Counts LAST, and after restoreStackEnable specifically: writing
            % hStackManager.enable re-runs the StackManager setters, which re-derive
            % numSlices/numVolumes and the frames<->volumes coupling. Restoring the
            % counts before that write would just be undone by it.
            obj.restoreAcqCounts(acqCounts, 'prime');

            obj.hSI.startLoop();      % arm: wait for the DAQ external trigger

            % Arming itself can re-apply the beam model, and that happens after
            % the restore above -- so check, but do NOT write: pushing powers
            % into a live armed acquisition is worse than the drift. If this
            % warns on the rig, the guard has to extend past startLoop.
            % Guarded: it runs AFTER arming, and a throw here would ack a failed
            % prime for a ScanImage that is in fact armed and ready.
            try, obj.checkBeamPowers(beamPowers, 'startLoop'); catch, end
            try, obj.checkAcqCounts(acqCounts, 'startLoop'); catch, end

            % Say what was actually armed. There was NO feedback on any of this,
            % which is why a wrong frame count stayed invisible until the data came
            % off the disk.
            %
            % Beam power and the plane list are here for a specific reason: the SLM
            % alignment script (holography2k align_slm_to_camera_scope2k) sets
            % hBeams.powers = 15, hStackManager.enable = 1 and arbitraryZs on this
            % machine via AutoCalibSI and never restores them. The prime's guards
            % PRESERVE whatever it finds -- correctly, since the GUI is
            % authoritative -- which means alignment residue is inherited silently
            % by the next experiment. Printing it is what makes it catchable.
            obj.report_armed();
            if ~isempty(obj.acq_drift)
                fprintf(['SIReceiver: the acquisition counts were first moved by ' ...
                         '''%s'' -- that is the call to fix.\n'], obj.acq_drift);
            end
        end

        function tf = getStackEnable(obj)
            % Current "Enable Stack" state ([] if unavailable). Property name
            % may differ across ScanImage versions — adjust here if needed.
            tf = [];
            try, tf = obj.hSI.hStackManager.enable; catch, end
        end

        function restoreStackEnable(obj, tf)
            if isempty(tf), return; end
            try, obj.hSI.hStackManager.enable = tf; catch, end
        end

        function p = getBeamPowers(obj)
            % Snapshot the imaging beam power ([] if unavailable). Property
            % names may differ across ScanImage versions -- adjust here if
            % needed; each field is optional and absent ones stay missing so
            % restoreBeamPowers only ever writes back what it actually read.
            %
            % pzAdjust is captured for the DIAGNOSTIC only and is deliberately
            % never restored: it is the power-vs-depth mode, and priming has no
            % business writing it either. Knowing whether it was on is what
            % tells us why powers moved.
            p = [];
            hb = [];
            try, hb = obj.hSI.hBeams; catch, end
            if isempty(hb), return; end
            p = struct();
            try, p.powers          = hb.powers;          catch, end
            try, p.powerFractions  = hb.powerFractions;  catch, end
            try, p.pzAdjust        = hb.pzAdjust;        catch, end
            if isempty(fieldnames(p)), p = []; end
        end

        function restoreBeamPowers(obj, p, where)
            % Put the captured beam power back, but only where it actually
            % drifted -- a well-behaved prime writes nothing at all. Says so out
            % loud when it does correct something: that line is the evidence for
            % which call moved the power.
            if isempty(p), return; end
            for f = {'powers', 'powerFractions'}
                name = f{1};
                if ~isfield(p, name), continue; end
                want = p.(name);
                got  = [];
                ok   = false;
                try, got = obj.hSI.hBeams.(name); ok = true; catch, end
                % isequal, not ==: these are vectors (one entry per beam), and
                % == on a length mismatch errors instead of saying "different".
                if ~ok || isequal(got, want), continue; end
                try
                    obj.hSI.hBeams.(name) = want;
                    fprintf(['SIReceiver: restored hBeams.%s at %s ' ...
                             '(%s -> %s)%s.\n'], name, where, ...
                        obj.fmt_power(got), obj.fmt_power(want), obj.pz_note(p));
                catch ME
                    warning('SIReceiver:beamPowerRestore', ...
                        'Could not restore hBeams.%s at %s: %s', ...
                        name, where, ME.message);
                end
            end
        end

        function checkBeamPowers(obj, p, where)
            % Report drift WITHOUT writing (see the startLoop call site).
            if isempty(p) || ~isfield(p, 'powers'), return; end
            got = [];
            try, got = obj.hSI.hBeams.powers; catch, return; end
            if isequal(got, p.powers), return; end
            warning('SIReceiver:beamPowerDrift', ...
                ['%s changed hBeams.powers (%s -> %s)%s, AFTER the guard ' ...
                 'restored it. Not writing to an armed acquisition -- the ' ...
                 'guard needs to extend past %s.'], ...
                where, obj.fmt_power(p.powers), obj.fmt_power(got), ...
                obj.pz_note(p), where);
        end

        function s = fmt_power(~, v)
            if isempty(v)
                s = '[]';
            else
                s = ['[' strjoin(compose('%g', double(v(:))'), ' ') ']'];
            end
        end

        function c = getAcqCounts(obj)
            % Snapshot the operator's # Frames / # Volumes ([] if unavailable).
            %
            % Same conventions as getBeamPowers, and for the same reason: each
            % property is read individually inside try/catch, so one that this
            % ScanImage version does not expose stays ABSENT from the struct rather
            % than erroring or turning up as []. restoreAcqCounts then only ever
            % writes back a field it actually managed to read.
            c = [];
            hsm = [];
            try, hsm = obj.hSI.hStackManager; catch, end
            if isempty(hsm), return; end
            c = struct();
            for f = obj.ACQ_COUNT_PROPS
                try, c.(f{1}) = hsm.(f{1}); catch, end   %#ok<AGROW>
            end
            if isempty(fieldnames(c)), c = []; end
        end

        function restoreAcqCounts(obj, c, where)
            % Put the operator's counts back, writing ONLY what actually drifted --
            % so a prime that leaves them alone writes nothing at all. That
            % neutrality matters here more than for beam powers: these properties
            % are coupled, and a redundant write to one re-derives the others.
            if isempty(c), return; end
            for f = obj.ACQ_COUNT_PROPS
                name = f{1};
                if ~isfield(c, name), continue; end
                want = c.(name);
                got  = [];
                ok   = false;
                try, got = obj.hSI.hStackManager.(name); ok = true; catch, end
                if ~ok || isequal(got, want), continue; end
                try
                    obj.hSI.hStackManager.(name) = want;
                    fprintf(['SIReceiver: restored hStackManager.%s at %s ' ...
                             '(%s -> %s).\n'], name, where, ...
                        obj.fmt_power(got), obj.fmt_power(want));
                catch ME
                    % numVolumes is read-only while the stack is disabled in some
                    % ScanImage versions, so a failure here is informative, not fatal.
                    warning('SIReceiver:acqCountRestore', ...
                        'Could not restore hStackManager.%s at %s: %s', ...
                        name, where, ME.message);
                end
            end
        end

        function checkAcqCounts(obj, c, where)
            % Report drift WITHOUT writing. Same reasoning as checkBeamPowers: this
            % runs after startLoop, and pushing acquisition geometry into an armed
            % acquisition is worse than the drift. If this warns on the rig, arming
            % itself is re-deriving the counts and the restore above cannot fix it --
            % the sequence has to change instead.
            if isempty(c), return; end
            now = obj.getAcqCounts();
            if isempty(now) || isequaln(now, c), return; end
            warning('SIReceiver:acqCountDrift', ...
                ['%s changed the acquisition counts (%s -> %s) AFTER the guard ' ...
                 'restored them.\nNot writing to an armed acquisition -- the guard ' ...
                 'cannot fix this one, the prime sequence has to change.'], ...
                where, obj.fmt_counts(c), obj.fmt_counts(now));
        end

        function noteAcqDrift(obj, c, where)
            % Record the FIRST prime step at which the counts moved, and say so once.
            % Which of abort / updateView / the user-function swap / the Stack
            % restore moves them cannot be worked out off the rig -- ScanImage's
            % source lives on the SI machine -- so the prime reports it instead of
            % guessing. Only the first is recorded: every later step would report the
            % same drift and bury the one that actually caused it.
            if isempty(c) || ~isempty(obj.acq_drift), return; end
            now = [];
            try, now = obj.getAcqCounts(); catch, return; end
            if isempty(now) || isequaln(now, c), return; end
            obj.acq_drift = where;
            fprintf(['SIReceiver: ''%s'' moved the acquisition counts (%s -> %s); ' ...
                     'restoring before arming.\n'], where, obj.fmt_counts(c), ...
                obj.fmt_counts(now));
        end

        function report_armed(obj)
            %REPORT_ARMED One line stating what the acquisition was actually armed with.
            %   Everything here is state the prime PRESERVES rather than sets, so a
            %   stale value left by an earlier alignment or grab would otherwise be
            %   invisible until the data came off the disk.
            fprintf('ScanImage armed. %s', obj.fmt_counts(obj.getAcqCounts()));

            bp = obj.getBeamPowers();
            if ~isempty(bp) && isfield(bp, 'powers')
                fprintf(' | beam %s%s', obj.fmt_power(bp.powers), obj.pz_note(bp));
            end

            st = obj.getStackEnable();
            if ~isempty(st)
                fprintf(' | stack %s', obj.onoff(st));
            end

            % arbitraryZs is set by the alignment script and by nothing in the prime,
            % so report the plane COUNT (the full list would swamp the line).
            try
                zs = obj.hSI.hStackManager.arbitraryZs;
                if ~isempty(zs), fprintf(' | %d arbitraryZs', numel(zs)); end
            catch
            end

            [fns, ok] = obj.enabled_user_functions();
            if ~ok
                fprintf(' | user fns: ?');       % unreadable, NOT "none enabled"
            elseif isempty(fns)
                fprintf(' | user fns: NONE');
            else
                fprintf(' | user fns: %s', strjoin(fns, ','));
            end
            fprintf('\n');
        end

        function s = onoff(~, tf)
            if isempty(tf), s = '?'; elseif any(tf(:)), s = 'ON'; else, s = 'off'; end
        end

        function s = fmt_counts(obj, c)
            if isempty(c), s = 'counts unavailable'; return; end
            parts = {};
            for f = obj.ACQ_COUNT_PROPS
                if isfield(c, f{1})
                    parts{end+1} = sprintf('%s=%s', f{1}, obj.fmt_power(c.(f{1}))); %#ok<AGROW>
                end
            end
            if isempty(parts), s = 'counts unavailable'; else, s = strjoin(parts, ' '); end
        end

        function s = pz_note(~, p)
            % pzAdjust on is the usual explanation for powers moving by itself.
            s = '';
            if isfield(p, 'pzAdjust') && ~isempty(p.pzAdjust) && any(p.pzAdjust(:))
                s = ' [pzAdjust was ON]';
            end
        end

        function onFinish(obj)
            % End of a normal recording: let ScanImage finish the CURRENT
            % acquisition (its frame timer runs out) and THEN stop the LOOP.
            % NOT an immediate abort (that would truncate the in-progress tiff).
            try, obj.hSI = evalin('base', 'hSI'); catch, end
            beamPowers = [];
            try, beamPowers = obj.getBeamPowers(); catch, end
            try, obj.hSI.extTrigEnable = 0; catch, end   % don't start another acquisition
            t0 = tic;
            while toc(t0) < 60
                st = '';
                try, st = lower(char(obj.hSI.acqState)); catch, end
                % idle / loop_wait => the current acquisition has finished; safe
                % to stop. grab / loop / focus => still acquiring; keep waiting.
                % (acqState strings can vary by ScanImage version — adjust here.)
                if isempty(st) || any(strcmp(st, {'idle', 'loop_wait'}))
                    break
                end
                pause(0.05);
            end
            try, obj.hSI.abort(); catch, end   % exit the loop now the acq is done
            % The abort above is one of the suspects for moving the power, so
            % end-of-run gets the same guard as the prime. Never let it throw:
            % this runs inside the listener loop.
            try, obj.restoreBeamPowers(beamPowers, 'finish'); catch, end
            disp('ScanImage: current acquisition finished; loop stopped.')
        end

        function onAbort(obj)
            % Cancel the armed acquisition primed for the aborted experiment.
            try, obj.hSI = evalin('base', 'hSI'); catch, end
            beamPowers = [];
            try, beamPowers = obj.getBeamPowers(); catch, end
            try, obj.hSI.abort(); catch, end
            try, obj.restoreBeamPowers(beamPowers, 'abort'); catch, end
            disp('ScanImage priming aborted.')
        end

        function stamp = date_stamp(obj)
            % Prefer the prime's date so tiffs line up with the DAQ save file.
            if isstruct(obj.config) && isfield(obj.config, 'date') && ~isempty(obj.config.date)
                stamp = char(obj.config.date);
            else
                stamp = char(datetime('now', 'Format', 'yyMMdd'));
            end
        end

        function set_user_function(obj)
            % Enable the experiment's ScanImage user function (from the prime's
            % si_callback). ADDITIVE: nothing is ever disabled.
            %
            % This used to call disable_all_user_functions first, which set
            % Enable = 0 on EVERY entry in userFunctionsCfg and then enabled only
            % the one named by si_callback. Since every si_callback in every
            % manifest is '', the effect was that the first prime of a session
            % turned off arm_reset_callback and online_analysis_callback and never
            % turned them back on -- online analysis was silently dead from the
            % first Prepare onwards, with nothing printed.
            %
            % Per the operator (2026-08-05): user functions are managed BY HAND in
            % the ScanImage GUI, so priming must not touch them. The trade, stated
            % plainly: with nothing disabled, a user function enabled for one
            % experiment stays enabled for the next. That is now deliberate --
            % ScanImage's checkboxes are the single source of truth, the same call
            % the # Frames / beam power guards make.
            %
            % disable_all_user_functions is kept as a manual utility (call it from
            % the prompt on the SI box) but is no longer part of the prime.
            cb = '';
            if isstruct(obj.config) && isfield(obj.config, 'si_callback')
                cb = char(obj.config.si_callback);
            end
            if ~isempty(cb)
                obj.enable_user_function(cb);
                fprintf('SIReceiver: enabled user function ''%s'' (others left as-is).\n', cb);
            end
        end

        function disable_all_user_functions(obj)
            %DISABLE_ALL_USER_FUNCTIONS Manual utility -- NOT called by the prime.
            %   Priming deliberately leaves the operator's user-function checkboxes
            %   alone (see set_user_function). Call this by hand when you actually
            %   want everything off.
            for ii = 1:numel(obj.hSI.hUserFunctions.userFunctionsCfg)
                obj.hSI.hUserFunctions.userFunctionsCfg(ii).Enable = 0;
            end
        end

        function [names, ok] = enabled_user_functions(obj)
            %ENABLED_USER_FUNCTIONS Names of the currently enabled user functions.
            %   [names, ok] = ... ; ok is false when the list could not be READ at
            %   all, which is not the same as "none are enabled" -- reporting an
            %   unreadable list as NONE would assert something untrue about which
            %   callbacks are about to fire.
            %
            %   Reported at arm time so it is visible which callbacks will run --
            %   necessary now that the prime no longer forces them off, and the
            %   thing that would have made the silent-online-analysis bug obvious.
            names = {};
            ok = false;
            try
                cfg = obj.hSI.hUserFunctions.userFunctionsCfg;
                on = arrayfun(@(c) ~isempty(c.Enable) && any(c.Enable), cfg);
                names = {cfg(on).UserFcnName};
                ok = true;
            catch
            end
        end

        function enable_user_function(obj, user_function)
            idx = cellfun(@(x) strcmp(x, user_function), ...
                {obj.hSI.hUserFunctions.userFunctionsCfg.UserFcnName});
            if any(idx)
                obj.hSI.hUserFunctions.userFunctionsCfg(idx).Enable = 1;
            else
                warning('SIReceiver: user function "%s" not found in ScanImage.', user_function);
            end
        end
    end
end

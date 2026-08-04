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

            % Stop any prior looped acquisition before re-arming for a new expt.
            try, obj.hSI.abort(); catch, end

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

            obj.set_user_function();

            % Force the acquisition number back to 1 right before arming, so
            % stray trailing files don't auto-bump it to a higher number — we
            % want to overwrite from _00001. (Set last so nothing re-derives it.)
            obj.hSI.hScan2D.logFileCounter = 1;
            obj.restoreStackEnable(stackEnable);   % keep the user's Stack setting
            obj.restoreBeamPowers(beamPowers, 'prime');   % keep the user's power
            obj.hSI.startLoop();      % arm: wait for the DAQ external trigger

            % Arming itself can re-apply the beam model, and that happens after
            % the restore above -- so check, but do NOT write: pushing powers
            % into a live armed acquisition is worse than the drift. If this
            % warns on the rig, the guard has to extend past startLoop.
            % Guarded: it runs AFTER arming, and a throw here would ack a failed
            % prime for a ScanImage that is in fact armed and ready.
            try, obj.checkBeamPowers(beamPowers, 'startLoop'); catch, end
            disp('ScanImage armed.')
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
            % si_callback), disabling all others. No-op when si_callback is ''.
            obj.disable_all_user_functions();
            cb = '';
            if isstruct(obj.config) && isfield(obj.config, 'si_callback')
                cb = char(obj.config.si_callback);
            end
            if ~isempty(cb)
                obj.enable_user_function(cb);
            end
        end

        function disable_all_user_functions(obj)
            for ii = 1:numel(obj.hSI.hUserFunctions.userFunctionsCfg)
                obj.hSI.hUserFunctions.userFunctionsCfg(ii).Enable = 0;
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

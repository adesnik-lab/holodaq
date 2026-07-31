classdef RemoteControlAgent < handle
    %REMOTECONTROLAGENT Bridge between the phone-control server and the rig GUIs.
    %
    %   A single polling timer connects the MATLAB session (which cannot be a
    %   server) to the FastAPI broker. It reuses the EXISTING GUI classes rather
    %   than driving hardware directly:
    %       * idle  -> drives a PowerControllerCalibrated (laser/shutter/power)
    %       * run   -> hands the DAQ/serial to an ExperimentLauncher and drives
    %                  Prepare/Start/Abort, forwarding trial progress back.
    %
    %   Only ONE object owns Dev1 + COM4 at a time: the power controller when
    %   idle, the Experiment during a run. The agent releases the power app
    %   before an experiment prepares and re-creates it after the run's cleanup
    %   (daqreset) frees the hardware.
    %
    %   Concurrency: the poll timer uses BusyMode='drop', so while a blocking
    %   run() executes inside a tick, no second tick runs. During a run the only
    %   servicing happens in the per-trial TrialCompleted listener (the existing
    %   drawnow window), which posts status and polls for a remote stop.
    %
    %   Safety: laser-ON requires an explicit confirm; a laser watchdog auto-offs
    %   after LaserMaxOnSecs; E-STOP drives everything safe on demand. A phone
    %   that goes quiet does NOT trigger any safe-ing: the operator toggles their
    %   phone on/off while working, so the rig HOLDS its current state and the
    %   phone resyncs from the live status board when it reconnects. Commands are
    %   de-duplicated by id.
    %
    %   Usage (see start_remote.m):
    %       io = RemoteControlIO('http://127.0.0.1:8765/api', 'PIN');
    %       ag = RemoteControlAgent(io, 'Launcher', ExperimentLauncher);
    %       ag.start();

    properties
        io                                  % RemoteControlIO
        power                               % PowerControllerCalibrated ([] during a run)
        launcher                            % ExperimentLauncher ([] if disabled)
        poll                                % polling timer
        mode            char = 'idle'       % idle | preparing | prepared | running
        role            char = 'both'       % scope | launcher | both (both = dev/simulate)
        simulate        logical = false
        visible         logical = true

        % bookkeeping / safety
        seenIds         string = string.empty
        agentSeq        double = 0
        faults          cell = {}
        phoneEverSeen   logical = false
        phoneLost       logical = false   % edge-tracks phone/link drop for logging
        laserArmedUntil datetime = NaT
        expListeners    = []
        trackedExp      = []            % Experiment we've attached listeners to ([] = none)

        % satellite prime status (read from holochat config/*_status)
        holoIO                          % RESTio to the holochat broker ([] off-rig)
        satellites      struct = struct()
        satTick         double = 0
        satEvery        double = 5       % refresh satellites every Nth tick

        % simulate-mode fake experiment run
        simSelected     char = ''
        simTrial        double = 0
        simN            double = 0
        simTimer

        % tunables
        LaserMaxOnSecs  double = 1800   % laser watchdog: 30 min max-on
        PollPeriod      double = 0.4
    end

    methods
        function obj = RemoteControlAgent(io, varargin)
            p = inputParser;
            p.addParameter('Role', 'both');   % scope | launcher | both
            p.addParameter('Simulate', false);
            p.addParameter('Visible',  true);
            p.addParameter('Launcher', []);   % an ExperimentLauncher, or [] to disable experiments
            p.addParameter('Power',    []);   % an existing PowerControllerCalibrated, or [] to create one
            p.addParameter('HoloServer', holochat_server());   % broker for satellite acks
            p.parse(varargin{:});

            obj.io       = io;
            obj.role     = char(p.Results.Role);
            obj.simulate = logical(p.Results.Simulate);
            obj.visible  = logical(p.Results.Visible);
            obj.launcher = p.Results.Launcher;

            % Client to the holochat broker: reads the satellites' prime acks
            % (config/{si,ptb,holo}_status, launcher side) and broadcasts the
            % abort signal (config/abort, both sides). Skipped in simulate.
            if ~obj.simulate
                try
                    obj.holoIO = RESTio(p.Results.HoloServer);
                catch
                    obj.holoIO = [];
                end
            end

            % Only the scope side owns the power hardware.
            if obj.hasScope()
                if isempty(p.Results.Power)
                    obj.acquirePower();
                else
                    obj.power = p.Results.Power;
                end
            end
        end

        function start(obj)
            obj.stop();   % never run two poll timers
            obj.poll = timer('Name', 'RemoteControlAgent', ...
                'ExecutionMode', 'fixedSpacing', 'BusyMode', 'drop', ...
                'Period', obj.PollPeriod, 'TimerFcn', @(~,~) obj.tick());
            start(obj.poll);
            simtag = '';
            if obj.simulate, simtag = ', SIMULATE'; end
            fprintf('RemoteControlAgent polling %s every %.1fs (mode=%s%s).\n', ...
                obj.io.base, obj.PollPeriod, obj.mode, simtag);
        end

        function stop(obj)
            if ~isempty(obj.poll) && isvalid(obj.poll)
                try, stop(obj.poll); catch, end
                try, delete(obj.poll); catch, end
            end
            obj.poll = [];
        end

        function pushStatus(obj)
            % Public: the launcher calls this on a local state change so the
            % phone reflects preparing/prepared/running without waiting for the
            % next tick. Also (re)attaches the experiment listeners now, so a
            % fast local Prepare->Start can't begin the blocking run() before the
            % agent is listening.
            if obj.hasLauncher() && ~obj.simulate
                try, obj.syncLauncherExp(); catch, end
            end
            obj.postStatus();
        end

        function delete(obj)
            obj.stop();
            obj.stopSimTimer();
            obj.detachExpListeners();
            if ~isempty(obj.power) && isvalid(obj.power)
                try, obj.power.releaseHardware(); catch, end
                try, delete(obj.power); catch, end
            end
        end
    end

    %% ---- main poll loop --------------------------------------------------
    methods (Access = private)
        function tick(obj)
            obj.faults = {};                 % faults reflect only this cycle
            try
                if obj.hasScope(), obj.safetyTick(); end
                cmds = obj.io.popCommands(obj.role);
                for k = 1:numel(cmds)
                    obj.handle(cmds{k});
                end
                if obj.hasLauncher()
                    obj.syncLauncherExp();   % track a GUI-started run too
                    obj.satTick = obj.satTick + 1;
                    if mod(obj.satTick, obj.satEvery) == 0
                        obj.refreshSatellites();
                    end
                end
            catch ME
                obj.addFault(sprintf('tick: %s', ME.message));
            end
            obj.postStatus();
        end

        function handle(obj, c)
            if ~isstruct(c) || ~isfield(c, 'type'), return; end
            id = obj.cmdId(c);
            if obj.isDup(id), return; end

            type = char(c.type);
            if ~obj.roleAllows(type)
                return   % handled by the other client (scope vs launcher)
            end
            obj.remember(id);

            args = obj.getargs(c);
            switch type
                case 'laser.set'
                    obj.requireIdlePower(@() obj.doLaser(c, args));
                case 'shutter.set'
                    obj.requireIdlePower(@() obj.power.shutter(args.channel, logical(args.open)));
                case 'power.set'
                    obj.requireIdlePower(@() obj.power.setPowerMW(args.channel, args.mW));
                case 'pulse'
                    obj.requireIdlePower(@() obj.power.firePulse(args.channel));
                case 'experiment.select'
                    obj.doSelect(args);
                case 'experiment.prepare'
                    obj.doPrepare(args);
                case 'experiment.start'
                    obj.doStart();
                case {'experiment.abort', 'estop'}
                    obj.doAbort(strcmp(type, 'estop'));
                otherwise
                    obj.addFault(sprintf('unknown command "%s"', type));
            end
        end

        function requireIdlePower(obj, fn)
            if ~strcmp(obj.mode, 'idle')
                obj.addFault('power command ignored (experiment active)');
                return
            end
            if isempty(obj.power) || ~isvalid(obj.power)
                obj.acquirePower();
            end
            try
                fn();
            catch ME
                obj.addFault(sprintf('power: %s', ME.message));
            end
        end
    end

    %% ---- power commands --------------------------------------------------
    methods (Access = private)
        function doLaser(obj, c, args)
            on = logical(args.on);
            if on
                if ~(isfield(c, 'confirm') && c.confirm)
                    obj.addFault('laser ON ignored (no confirm)');
                    return
                end
                obj.laserArmedUntil = datetime('now') + seconds(obj.LaserMaxOnSecs);
            else
                obj.laserArmedUntil = NaT;
            end
            obj.power.laser(on);
        end
    end

    %% ---- experiment commands --------------------------------------------
    methods (Access = private)
        function doSelect(obj, args)
            name = obj.field(args, 'name', '');
            if obj.simulate
                obj.simSelected = char(name);
                return
            end
            if isempty(obj.launcher) || ~isvalid(obj.launcher)
                obj.addFault('no launcher (experiments disabled)');
                return
            end
            if ~isempty(name), obj.launcher.remoteSelect(char(name)); end
        end

        function doPrepare(obj, args)
            if ~strcmp(obj.currentMode(), 'idle')
                obj.addFault('prepare ignored (not idle)');
                return
            end
            ov = obj.field(args, 'overrides', struct());

            if obj.simulate
                if isfield(args, 'name'), obj.simSelected = char(args.name); end
                obj.simN = obj.field(ov, 'n_trials', 10);
                obj.mode = 'prepared';
                return
            end

            if isempty(obj.launcher) || ~isvalid(obj.launcher)
                obj.addFault('no launcher (experiments disabled)');
                return
            end

            % Hand the DAQ/serial from the power controller to the experiment.
            obj.releasePower();
            obj.mode = 'preparing';
            obj.postStatus();

            if isfield(args, 'name'), obj.launcher.remoteSelect(char(args.name)); end
            policy = char(obj.field(args, 'overwrite', 'error'));
            ok = false;
            try
                ok = obj.launcher.remotePrepare(ov, policy);
            catch ME
                obj.addFault(sprintf('prepare: %s', ME.message));
            end
            if ok
                obj.mode = 'prepared';
                obj.ensureExpListeners(obj.launcher.getExperiment());
            else
                obj.mode = 'idle';
                obj.acquirePower();       % failed/aborted -> resume power control ('both' role)
            end
        end

        function doStart(obj)
            if ~strcmp(obj.currentMode(), 'prepared')
                obj.addFault('start ignored (nothing prepared)');
                return
            end

            if obj.simulate
                obj.startSimRun();
                return
            end

            exp = obj.launcher.getExperiment();
            if isempty(exp) || ~isvalid(exp)
                obj.addFault('start: no prepared experiment');
                obj.acquirePower();
                return
            end

            obj.ensureExpListeners(exp);   % (also attached by the tick for a local start)
            obj.mode = 'running';
            obj.postStatus();
            try
                obj.launcher.remoteStart();   % BLOCKS for the whole run
            catch ME
                obj.addFault(sprintf('run: %s', ME.message));
            end
            obj.clearExpListeners();

            % The run's cleanup ran daqreset(); reclaim the hardware for idle
            % power control ('both' role; no-op for launcher role).
            obj.mode = 'idle';
            obj.acquirePower();
        end

        function doAbort(obj, isEstop)
            if isEstop && ~isempty(obj.power) && isvalid(obj.power)
                try, obj.power.allSafe(); catch, end
                obj.laserArmedUntil = NaT;
            end

            % Cancel satellite priming. When a launcher is attached it does this
            % itself (ExperimentLauncher.onAbort, so a local GUI abort works too);
            % only broadcast here for a scope-only client (E-STOP, no launcher).
            if ~obj.hasLauncher()
                obj.broadcastAbort();
            end

            if obj.simulate
                obj.stopSimTimer();
                obj.mode = 'idle';
                return
            end

            if ~isempty(obj.launcher) && isvalid(obj.launcher)
                try
                    obj.launcher.remoteAbort();
                catch ME
                    obj.addFault(sprintf('abort: %s', ME.message));
                end
            end

            % Reachable only when NOT mid-run (a run blocks the tick; its abort
            % is handled in pollForStop). If the launcher tore down to idle,
            % resume power control.
            if ~strcmp(obj.mode, 'running') && strcmp(obj.launcherState(), 'idle')
                obj.mode = 'idle';
                obj.acquirePower();
            end
        end
    end

    %% ---- in-run event listeners -----------------------------------------
    methods (Access = private)
        function attachExpListeners(obj, exp)
            obj.detachExpListeners();
            obj.expListeners = [ ...
                addlistener(exp, 'TrialCompleted', @(s, e) obj.onTrialRemote(e)); ...
                addlistener(exp, 'RunFinished',    @(s, e) obj.postStatus()); ...
                addlistener(exp, 'StatusChanged',  @(s, e) obj.postStatus()) ];
        end

        function detachExpListeners(obj)
            for k = 1:numel(obj.expListeners)
                try
                    if isvalid(obj.expListeners(k)), delete(obj.expListeners(k)); end
                catch
                end
            end
            obj.expListeners = [];
        end

        function syncLauncherExp(obj)
            % Track whatever Experiment the launcher currently holds, so a run
            % started from the local GUI still forwards trial progress + honors
            % a remote stop (the listeners fire in the run's drawnow).
            exp = [];
            if ~isempty(obj.launcher) && isvalid(obj.launcher)
                exp = obj.launcher.getExperiment();
            end
            if ~isempty(exp) && isvalid(exp)
                obj.ensureExpListeners(exp);
            else
                obj.clearExpListeners();
            end
        end

        function ensureExpListeners(obj, exp)
            if isempty(exp) || ~isvalid(exp), return; end
            same = ~isempty(obj.trackedExp) && isvalid(obj.trackedExp) && (obj.trackedExp == exp);
            if ~same
                obj.attachExpListeners(exp);
                obj.trackedExp = exp;
            end
        end

        function clearExpListeners(obj)
            if ~isempty(obj.trackedExp)
                obj.detachExpListeners();
                obj.trackedExp = [];
            end
        end

        function onTrialRemote(obj, ~)
            % Fires inside notify_progress's drawnow (once per trial): report
            % progress and check for a remote stop. This is the only servicing
            % window while the blocking run() holds the thread.
            obj.postStatus();
            obj.pollForStop();
        end

        function pollForStop(obj)
            cmds = obj.io.popCommands(obj.role);
            for k = 1:numel(cmds)
                c = cmds{k};
                if ~isstruct(c) || ~isfield(c, 'type'), continue; end
                id = obj.cmdId(c);
                if obj.isDup(id), continue; end
                obj.remember(id);
                t = char(c.type);
                if any(strcmp(t, {'experiment.abort', 'estop'}))
                    if ~isempty(obj.launcher) && isvalid(obj.launcher)
                        % sets AbortRequested (honored at the next trial boundary)
                        % AND broadcasts the satellite abort.
                        obj.launcher.remoteAbort();
                    end
                else
                    obj.addFault(sprintf('"%s" ignored during run', t));
                end
            end
        end
    end

    %% ---- status board ----------------------------------------------------
    methods (Access = private)
        function postStatus(obj)
            obj.agentSeq = obj.agentSeq + 1;
            s = struct();
            s.agent_seq = obj.agentSeq;
            s.faults    = obj.faults;
            % Post only the sections this role owns; the server merges by role
            % so scope and launcher don't clobber each other's status.
            if obj.hasScope()
                s.power = obj.powerStatus();
            end
            if obj.hasLauncher()
                s.mode       = obj.currentMode();   % launcher's true State (local or remote)
                s.experiment = obj.expStatus();
                s.satellites = obj.satellites;
            end
            obj.io.postStatus(s, obj.role);
        end

        function refreshSatellites(obj)
            % Pull each satellite's latest prime ack from config/*_status.
            if isempty(obj.holoIO), return; end
            sat = struct();
            sat.si   = obj.readSatelliteStatus('si_status');
            sat.ptb  = obj.readSatelliteStatus('ptb_status');
            sat.holo = obj.readSatelliteStatus('holo_status');
            obj.satellites = sat;
        end

        function st = readSatelliteStatus(obj, topic)
            % Read + decode one config/*_status ack. Tolerates both MATLAB
            % (mps) and plain-JSON (Python/PTB) encodings; [] if none.
            st = [];
            try
                recv = obj.holoIO.scan(topic, 'config');
                if isempty(recv) || ~isstruct(recv) || ~isfield(recv, 'message')
                    return
                end
                try
                    st = mps.json.decode(recv.message);
                catch
                    st = jsondecode(recv.message);
                end
            catch
            end
        end

        function broadcastAbort(obj)
            % Post an incrementing abort_seq to the shared config/abort topic;
            % each satellite listener cancels its priming when the seq rises.
            if isempty(obj.holoIO), return; end
            try
                obj.holoIO.post(struct('abort_seq', posixtime(datetime('now'))), ...
                    'abort', 'daq', 'config');
            catch ME
                obj.addFault(sprintf('abort broadcast: %s', ME.message));
            end
        end

        function ps = powerStatus(obj)
            if ~isempty(obj.power) && isvalid(obj.power)
                st = obj.power.state();
                ps = struct('laser_on', st.laser_on, 'laser_voltage', st.laser_voltage, ...
                    'ch900', st.ch900, 'ch1100', st.ch1100);
            else
                % power app released during a run: report a safe placeholder.
                blank = struct('shutter_open', false, 'power_mW', [], 'range_mW', [], 'calibrated', false);
                ps = struct('laser_on', false, 'laser_voltage', 0, 'ch900', blank, 'ch1100', blank);
            end
        end

        function es = expStatus(obj)
            if obj.simulate
                es = struct('selected', obj.simSelected, 'state', obj.mode, ...
                    'trial', obj.simTrial, 'n_trials', obj.simN, ...
                    'eta_secs', max(0, (obj.simN - obj.simTrial) * 0.5), 'message', '');
                return
            end
            if ~isempty(obj.launcher) && isvalid(obj.launcher)
                es = obj.launcher.remoteStatus();
            else
                es = struct('selected', '', 'state', 'idle', 'trial', 0, ...
                    'n_trials', 0, 'eta_secs', [], 'message', 'experiments disabled');
            end
        end

        function st = launcherState(obj)
            st = 'idle';
            if ~isempty(obj.launcher) && isvalid(obj.launcher)
                s = obj.launcher.remoteStatus();
                st = s.state;
            end
        end

        function m = currentMode(obj)
            % Truth for the launcher role is the launcher's own State, so a
            % GUI-driven Prepare/Start/Abort is reflected on the phone; scope /
            % simulate keep the agent's local mode.
            if obj.simulate || ~obj.hasLauncher()
                m = obj.mode;
            else
                m = obj.launcherState();
            end
        end
    end

    %% ---- safety ----------------------------------------------------------
    methods (Access = private)
        function safetyTick(obj)
            % Time-based laser watchdog + phone-link edge logging. A phone
            % going quiet NO LONGER drives the rig safe: the operator toggles
            % their phone on/off while working, so we HOLD the current hardware
            % state and let the phone resync from the live status board when it
            % reconnects (web/app.js render() repaints laser/shutter/power from
            % powerStatus() on every poll). Explicit safe-ing is still available
            % via E-STOP.
            now_ = datetime('now');
            hb = obj.io.readHeartbeat();
            serverOk = isfield(hb, 'ok') && hb.ok;
            phoneStale = ~isfield(hb, 'phone_stale') || logical(hb.phone_stale);
            if isfield(hb, 'phone_last_seen') && hb.phone_last_seen > 0
                obj.phoneEverSeen = true;
            end

            % Log the drop/reconnect transitions (no hardware action either
            % way) so the "state held across a phone toggle" behavior is
            % observable on the rig console.
            lost = (~serverOk) || phoneStale;
            if obj.phoneEverSeen && lost && ~obj.phoneLost
                obj.phoneLost = true;
                fprintf('[RemoteControlAgent] phone/link lost - holding current rig state.\n');
            elseif obj.phoneLost && serverOk && ~phoneStale
                obj.phoneLost = false;
                fprintf('[RemoteControlAgent] phone reconnected - it will resync from live status.\n');
            end

            % Laser watchdog: auto-off once the armed window elapses (time-based,
            % independent of the phone link).
            if ~isnat(obj.laserArmedUntil) && now_ > obj.laserArmedUntil
                obj.makeLaserSafe('laser auto-off (watchdog)');
                obj.laserArmedUntil = NaT;
            end
        end

        function makeLaserSafe(obj, msg)
            if strcmp(obj.mode, 'idle') && ~isempty(obj.power) && isvalid(obj.power)
                try
                    st = obj.power.state();
                    if st.laser_on
                        obj.power.laser(false);
                        obj.addFault(msg);
                    end
                catch
                end
            end
        end
    end

    %% ---- hardware ownership ----------------------------------------------
    methods (Access = private)
        function acquirePower(obj)
            if ~obj.hasScope(), return; end   % launcher role never owns power
            if ~isempty(obj.power) && isvalid(obj.power), return; end
            try
                obj.power = PowerControllerCalibrated('Simulate', obj.simulate, 'Visible', obj.visible);
            catch ME
                obj.power = [];
                obj.addFault(sprintf('power init: %s', ME.message));
            end
        end

        function releasePower(obj)
            if ~isempty(obj.power) && isvalid(obj.power)
                try, obj.power.releaseHardware(); catch, end
                try, delete(obj.power); catch, end
            end
            obj.power = [];
        end
    end

    %% ---- simulate-mode fake run ------------------------------------------
    methods (Access = private)
        function startSimRun(obj)
            obj.mode = 'running';
            obj.simTrial = 0;
            if obj.simN <= 0, obj.simN = 10; end
            obj.stopSimTimer();
            obj.simTimer = timer('Name', 'RemoteControlAgentSim', ...
                'ExecutionMode', 'fixedSpacing', 'BusyMode', 'drop', ...
                'Period', 0.5, 'TimerFcn', @(~, ~) obj.simTick());
            start(obj.simTimer);
        end

        function simTick(obj)
            obj.simTrial = obj.simTrial + 1;
            if obj.simTrial >= obj.simN
                obj.stopSimTimer();
                obj.mode = 'idle';
            end
            obj.postStatus();
        end

        function stopSimTimer(obj)
            if ~isempty(obj.simTimer) && isvalid(obj.simTimer)
                try, stop(obj.simTimer); catch, end
                try, delete(obj.simTimer); catch, end
            end
            obj.simTimer = [];
        end
    end

    %% ---- role helpers ----------------------------------------------------
    methods (Access = private)
        function tf = hasScope(obj)
            tf = any(strcmp(obj.role, {'scope', 'both'}));
        end

        function tf = hasLauncher(obj)
            tf = any(strcmp(obj.role, {'launcher', 'both'}));
        end

        function tf = roleAllows(obj, type)
            % Which command types this agent acts on, by role. estop is honored
            % by whichever client is up (scope -> allSafe, launcher -> abort).
            scopeCmds    = {'laser.set', 'shutter.set', 'power.set', 'pulse'};
            launcherCmds = {'experiment.select', 'experiment.prepare', ...
                            'experiment.start', 'experiment.abort'};
            if strcmp(type, 'estop')
                tf = true;
            elseif any(strcmp(type, scopeCmds))
                tf = obj.hasScope();
            elseif any(strcmp(type, launcherCmds))
                tf = obj.hasLauncher();
            else
                tf = true;   % unknown -> let handle() log it
            end
        end
    end

    %% ---- small helpers ---------------------------------------------------
    methods (Access = private)
        function a = getargs(~, c)
            a = struct();
            if isfield(c, 'args') && isstruct(c.args)
                a = c.args;
            end
        end

        function v = field(~, s, name, default)
            if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
                v = s.(name);
            else
                v = default;
            end
        end

        function id = cmdId(~, c)
            if isfield(c, 'id') && ~isempty(c.id)
                id = string(c.id);
            else
                id = "";
            end
        end

        function tf = isDup(obj, id)
            tf = id ~= "" && any(obj.seenIds == id);
        end

        function remember(obj, id)
            if id == "", return; end
            obj.seenIds(end + 1) = id;
            if numel(obj.seenIds) > 200
                obj.seenIds = obj.seenIds(end - 199:end);
            end
        end

        function addFault(obj, msg)
            fprintf('[RemoteControlAgent] %s\n', msg);
            obj.faults{end + 1} = msg;
            if numel(obj.faults) > 5
                obj.faults = obj.faults(end - 4:end);
            end
        end
    end
end

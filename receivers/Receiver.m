classdef Receiver < handle
    %RECEIVER Persistent satellite listener that primes on each experiment.
    %   A satellite computer (SI / PTB) runs one Receiver in a dedicated MATLAB
    %   session. listen() blocks forever, polling this box's holochat `config`
    %   topic; whenever the DAQ master broadcasts a NEW prime (a higher
    %   prime_seq, see prime_info.m), it calls the subclass run() to set the box
    %   up for that experiment and posts an ack to `config/<name>_status`.
    %
    %   The config channel is persistent (re-readable), so prime_seq is what
    %   distinguishes a freshly-primed experiment from a re-read of the same
    %   message.
    %
    %   Subclass contract: override run(), using obj.config (the prime struct).
    %
    %   See also: SIReceiver, start_si_listener, prime_info, HolochatInterface

    properties
        name
        interface
        config
        last_prime_seq = -inf
        last_abort_seq = -inf
        last_finish_seq = -inf
        poll_period = 0.25   % s between config polls once a prime is present
        poll                 % async timer ([] unless listen_async is running)
    end

    properties (Access = private)
        consecutive_errors = 0
        ERROR_REPORT_EVERY = 40   % ~10 s at the default poll_period
    end

    methods
        function obj = Receiver(name)
            obj.name = name;
            % reset=false: we READ config/<name>; never wipe what the DAQ posted.
            obj.interface = HolochatInterface(name, [], false);
        end

        function listen(obj)
            %LISTEN Blocking listener. Owns this MATLAB session until Ctrl-C.
            %   Use listen_async instead when the session has to stay usable --
            %   which on the ScanImage computer it does, because hSI lives in
            %   that session's base workspace and nothing else can reach it.
            obj.flush_stale();
            fprintf('[%s] listener up (BLOCKING; Ctrl-C to stop); waiting for a prime...\n', ...
                obj.name);
            while true
                obj.tick();
                pause(obj.poll_period);   % throttle the (persistent) config polling
            end
        end

        function t = listen_async(obj)
            %LISTEN_ASYNC Same listener on a timer, leaving the prompt free.
            %   t = obj.listen_async()   % also stored in obj.poll
            %
            %   Runs one tick() per poll_period on MATLAB's event queue, so you can
            %   keep working in the same session. obj.stop() to halt, obj.status()
            %   to check it is alive.
            %
            %   TWO THINGS TO KNOW, both inherent to timers rather than to this code:
            %
            %   1. The event queue is serviced only when MATLAB is idle or hits
            %      pause/drawnow/waitfor. A long blocking operation at the prompt --
            %      your loop, a big load, a slow network read, a modal dialog --
            %      DELAYS ticks. status() reports the achieved period so you can see
            %      when that is happening.
            %   2. run() can therefore fire in the middle of your interactive work.
            %      SIReceiver.run aborts, re-arms and swaps user functions, and
            %      onFinish can hold a tick for up to 60 s; BusyMode 'drop' prevents
            %      tick-vs-tick overlap but NOT tick-vs-you. Do not hand-drive hSI
            %      while a prime may land.
            obj.stop();   % never run two poll timers (see RemoteControlAgent.start)
            obj.flush_stale();
            obj.poll = timer('Name', sprintf('%sReceiver', obj.name), ...
                'ExecutionMode', 'fixedSpacing', ...  % space AFTER the callback: a slow
                'BusyMode', 'drop', ...               % run() must not build a backlog
                'Period', obj.poll_period, ...
                'TimerFcn', @(~, ~) obj.tick(), ...
                'ErrorFcn', @(src, evt) obj.on_timer_error(src, evt));
            start(obj.poll);
            fprintf(['[%s] listener up (ASYNC, every %.2f s; obj.stop() to halt, ' ...
                     'obj.status() to check); waiting for a prime...\n'], ...
                obj.name, obj.poll_period);
            t = obj.poll;
        end

        function stop(obj)
            %STOP Halt the async listener. No-op if it is not running.
            if ~isempty(obj.poll) && isvalid(obj.poll)
                try, stop(obj.poll); catch, end
                try, delete(obj.poll); catch, end
                fprintf('[%s] async listener stopped.\n', obj.name);
            end
            obj.poll = [];
        end

        function s = status(obj)
            %STATUS Am I actually listening? One call instead of a timerfindall hunt.
            %   Answers the question a timer makes hard: it can be stopped by an
            %   error, or be running but starved by something blocking the prompt.
            s = struct('mode', 'not running', 'running', false, ...
                       'period', obj.poll_period, 'achieved_period', NaN, ...
                       'last_prime_seq', obj.last_prime_seq, 'stem', obj.stem());
            if ~isempty(obj.poll) && isvalid(obj.poll)
                s.mode = 'async';
                s.running = strcmp(obj.poll.Running, 'on');
                s.achieved_period = obj.poll.AveragePeriod;
            end
            fprintf('[%s] %s', obj.name, s.mode);
            if s.running
                fprintf(', running');
                if ~isnan(s.achieved_period)
                    fprintf(' (target %.2f s, achieved %.2f s', s.period, s.achieved_period);
                    if s.achieved_period > 3 * s.period
                        fprintf(' -- STARVED, something is blocking the prompt');
                    end
                    fprintf(')');
                end
            elseif strcmp(s.mode, 'async')
                fprintf(', STOPPED (timer exists but is not running -- see any error above)');
            end
            fprintf('; last prime seq %g, stem %s\n', s.last_prime_seq, s.stem);
        end

        function tick(obj)
            %TICK One poll iteration: the body both listen() and listen_async() drive.
            %   Never throws. Under a timer an escaping error STOPS the timer, which
            %   would leave a listener that looks up but is dead; in the blocking loop
            %   it would kill the loop outright. Either way a broker hiccup must not
            %   end the session, so errors are caught, reported and retried -- the same
            %   thing poll_abort/poll_finish/flush_stale already did individually.
            try
                cfg = obj.poll_prime();
                if ~isempty(cfg)
                    obj.config = cfg;
                    try
                        obj.run();
                        obj.ack(true, 'primed');
                        fprintf('[%s] primed for %s\n', obj.name, obj.stem());
                    catch err
                        obj.ack(false, err.message);
                        fprintf('[%s] prime FAILED: %s\n', obj.name, err.message);
                    end
                end
                obj.poll_abort();
                obj.poll_finish();
                obj.note_ok();
            catch err
                obj.note_error(err);
            end
        end

        function poll_abort(obj)
            % When the DAQ broadcasts a new abort (config/abort abort_seq rises),
            % cancel this box's priming via the subclass onAbort(). The first
            % sighting only adopts a baseline so a stale abort doesn't fire.
            a = [];
            try, a = obj.interface.scan_config('abort'); catch, end
            if ~(isstruct(a) && isfield(a, 'abort_seq') && ~isempty(a.abort_seq))
                return
            end
            if isinf(obj.last_abort_seq)
                obj.last_abort_seq = a.abort_seq;      % baseline; do not fire
            elseif a.abort_seq > obj.last_abort_seq
                obj.last_abort_seq = a.abort_seq;
                try
                    obj.onAbort();
                    fprintf('[%s] priming aborted by DAQ.\n', obj.name);
                catch err
                    fprintf('[%s] abort handler error: %s\n', obj.name, err.message);
                end
            end
        end

        function flush_stale(obj)
            % On startup, drop stale messages from a previous session: clear the
            % consume-once msg inbox, and adopt the current prime as the baseline
            % so an old prime left on the config channel isn't re-run. (abort /
            % finish baseline themselves on first sighting.)
            try, obj.interface.flush(); catch, end
            c = [];
            try, c = obj.interface.scan_config(obj.name); catch, end
            if isstruct(c) && isfield(c, 'prime_seq') && ~isempty(c.prime_seq)
                obj.last_prime_seq = c.prime_seq;
            end
        end

        function cfg = poll_prime(obj)
            % Return the prime config only when a NEW prime_seq arrives, else [].
            cfg = [];
            % scan_config, not get_config: get_config is io.read, which busy-waits
            % up to 30 s in a loop with NO pause, so between experiments this
            % hammered the broker and made listen()'s pause(poll_period) below
            % meaningless. Non-blocking is all a polling loop needs -- and it is
            % what flush_stale two methods above already uses.
            %
            % This one call used to be UNGUARDED while poll_abort, poll_finish and
            % flush_stale all wrapped theirs, so a single network blip threw straight
            % out of listen()'s while loop and killed the listener. tick() catches it
            % now, but keep the guard local too: a transient read failure is not a
            % reason to fall out of one poll into the error path.
            c = [];
            try
                c = obj.interface.scan_config(obj.name);
            catch err
                obj.note_error(err);
                return
            end
            if isempty(c) || ~isstruct(c) || ~isfield(c, 'prime_seq'), return; end
            if c.prime_seq > obj.last_prime_seq
                obj.last_prime_seq = c.prime_seq;
                cfg = c;
            end
        end

        function s = stem(obj)
            if isstruct(obj.config) && isfield(obj.config, 'stem')
                s = obj.config.stem;
            else
                s = '?';
            end
        end

        function ack(obj, ok, message)
            % Report prime status back on a per-satellite config topic the DAQ
            % reads (config/<name>_status), so it never collides with the daq
            % msg inbox used by transferHR.
            a = struct('who', obj.name, 'ok', logical(ok), 'message', message);
            if isstruct(obj.config) && isfield(obj.config, 'prime_seq')
                a.prime_seq = obj.config.prime_seq;
            end
            a.stem = obj.stem();
            try
                obj.interface.set_config(a, [obj.name '_status']);
            catch
            end
        end

        function poll_finish(obj)
            % End-of-recording signal (config/<name>_finish): a graceful stop,
            % distinct from abort. Baseline the first sighting so a stale value
            % doesn't fire. Only SIReceiver overrides onFinish today.
            f = [];
            try, f = obj.interface.scan_config([obj.name '_finish']); catch, end
            if ~(isstruct(f) && isfield(f, 'finish_seq') && ~isempty(f.finish_seq))
                return
            end
            if isinf(obj.last_finish_seq)
                obj.last_finish_seq = f.finish_seq;
            elseif f.finish_seq > obj.last_finish_seq
                obj.last_finish_seq = f.finish_seq;
                try
                    obj.onFinish();
                    fprintf('[%s] end-of-recording stop.\n', obj.name);
                catch err
                    fprintf('[%s] finish handler error: %s\n', obj.name, err.message);
                end
            end
        end

        function on_timer_error(obj, src, ~)
            % ErrorFcn: a timer whose callback throws STOPS. tick() already catches
            % everything, so reaching here means something escaped it -- and the
            % listener is now dead while still looking like it was started. Say so
            % loudly, because there is no prompt returning to tell you.
            %
            % DELETE the timer, do not just drop the handle. MATLAB stops an errored
            % timer but leaves the object alive, so clearing obj.poll on its own
            % orphans it: still in timerfindall, invisible to status(), and a later
            % listen_async() cannot stop what it can no longer see. That is the zombie
            % timer this whole lifecycle exists to prevent. Take src (the timer that
            % errored) and obj.poll, since they can differ if the handle was replaced.
            for h = {src, obj.poll}
                t = h{1};
                if ~isempty(t) && isa(t, 'timer') && isvalid(t)
                    try, stop(t);   catch, end
                    try, delete(t); catch, end
                end
            end
            obj.poll = [];
            warning('Receiver:asyncStopped', ...
                ['[%s] ASYNC LISTENER STOPPED -- the poll timer errored, so this box ' ...
                 'is no longer being primed.\nRestart it with listen_async(). ' ...
                 '(status() reports "not running" from here on.)'], obj.name);
        end

        function note_error(obj, err)
            % Report a polling failure without spamming: the first one, then every
            % ERROR_REPORT_EVERY. A broker that is down produces one message every
            % ~10 s rather than four a second.
            obj.consecutive_errors = obj.consecutive_errors + 1;
            n = obj.consecutive_errors;
            if n == 1 || mod(n, obj.ERROR_REPORT_EVERY) == 0
                fprintf('[%s] poll error (%d in a row, still trying): %s\n', ...
                    obj.name, n, err.message);
            end
        end

        function note_ok(obj)
            if obj.consecutive_errors > 0
                fprintf('[%s] polling recovered after %d failed attempt(s).\n', ...
                    obj.name, obj.consecutive_errors);
                obj.consecutive_errors = 0;
            end
        end

        function run(obj)
            % overridden by subclass
        end

        function onAbort(obj)  %#ok<MANU>
            % overridden by subclass: cancel whatever run() primed
        end

        function onFinish(obj)  %#ok<MANU>
            % overridden by subclass: stop gracefully at end of recording
        end
    end
end

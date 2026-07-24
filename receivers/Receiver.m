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
    end

    methods
        function obj = Receiver(name)
            obj.name = name;
            % reset=false: we READ config/<name>; never wipe what the DAQ posted.
            obj.interface = HolochatInterface(name, [], false);
        end

        function listen(obj)
            fprintf('[%s] listener up; waiting for a prime from the DAQ...\n', obj.name);
            while true
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
                pause(obj.poll_period);   % throttle the (persistent) config polling
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

        function cfg = poll_prime(obj)
            % Return the prime config only when a NEW prime_seq arrives, else [].
            cfg = [];
            c = obj.interface.get_config();
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

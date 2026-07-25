classdef HolochatInterface < Interface
    properties
        id
    end

    methods
        function obj = HolochatInterface(id, server, reset)
            if nargin < 2 || isempty(server)
                server = rig_get('network.holochat_server', 'http://136.152.58.120:8000');
            end

            if nargin < 3 || isempty(reset)
                reset = true;
            end
            obj.id = id;
            obj.io = RESTio(server);
            if reset
                obj.io.reset(obj.id);
            end
        end
        
        function initialize(obj)
        end

        function send(obj, data, target)
            obj.io.post(data, target, obj.id, 'msg');
            pause(0.1);
        end

        function set_config(obj, data, target)
            obj.io.post(data, target, obj.id, 'config');
        end

        function out = get_config(obj)
            out = obj.io.read(obj.id, 30, 'config');
        end

        function out = scan_config(obj, topic)
            % Non-blocking single read of a config topic (default: self).
            % [] if unset. Used to poll the shared config/abort signal without
            % the 30 s busy-wait that get_config does. Decodes the MPS-typed
            % JSON the DAQ posts (prime / abort / finish).
            if nargin < 2 || isempty(topic), topic = obj.id; end
            out = obj.io.decode(obj.io.scan(topic, 'config'));
        end

        function out = scan_status(obj, topic)
            % Non-blocking read of a satellite ack topic (config/<name>_status).
            % Tolerates BOTH the MPS-typed JSON that MATLAB satellites post and
            % the plain JSON the Python (PTB) primer posts. [] if unset.
            out = [];
            raw = obj.io.scan(topic, 'config');
            if isempty(raw) || ~isstruct(raw) || ~isfield(raw, 'message')
                return
            end
            try
                out = mps.json.decode(raw.message);
            catch
                try, out = jsondecode(raw.message); catch, end
            end
        end

        function out = read(obj, timeout)
            if nargin < 2 || isempty(timeout)
                timeout = 10;
            end
            out = obj.io.read(obj.id, timeout, 'msg');
        end

        function flush(obj)
            obj.io.flush(obj.id);
        end
        

    end
end
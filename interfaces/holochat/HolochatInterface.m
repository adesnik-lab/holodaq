classdef HolochatInterface < Interface
    properties
        id
    end

    methods
        function obj = HolochatInterface(id, server, reset)
            if nargin < 2 || isempty(server)
                server = 'http://136.152.58.120:8000';
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
            obj.io.send(data, target, obj.id);
        end

        function out = read(obj, timeout, target)
            if nargin < 2 || isempty(timeout)
                timeout = 5;
            end
            
            if nargin < 3 || isempty(target)
                target = obj.id;
            end
            
            out = obj.io.read(target, timeout);
        end

        function flush(obj)
            obj.io.flush(obj.id);
        end
        

    end
end
classdef MSocketInterface < Interface
    properties
        ip
        port
        
        data
        socket
    end
    
    methods
        function obj = MSocketInterface()
            obj.ip = ip;
            obj.port = socket;
        end

        function initialize(obj)
            obj.socket = msconnect(obj.ip, obj.port);
            obj.validate_connection();
        end

        function validate_connection(obj)
            while ~strcmp(invar,'A')
                invar=msrecv(obj.socket,.5);
            end
            sendVar= 'B';
            mssend(obj.socket, sendVar);
            disp('input from hologram computer validated');
        end

        function set(obj, val)
            obj.data = val;
        end

        function out = get_data(obj)
            out = obj.data;
        end

        function validated = validate(obj, val)
            validated = false;
            if isa(val, 'char')
                validated = true;
            end
        end

        function send(obj, data)
            if nargin < 2 || isempty(data)
                data = obj.data;
            end
            % fprintf('sent ''%s''\n', data)
            mssend(obj.socket, obj.data);
        end

        function out =  receive(obj,  timeout)
            if nargin < 2 || isempty(timeout)
                timeout = 0.5; % sec
            end

            out = msrecv(obj.socket, timeout);
        end
    end
end


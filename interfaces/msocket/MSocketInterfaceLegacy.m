classdef MSocketInterfaceLegacy < Interface
    properties
        port
        
        data
        socket
    end
    
    methods
        function obj = MSocketInterfaceLegacy(port)
            obj.port = str2double(port);
        end

        function connect(obj)
            temporary_sock = mslisten(obj.port);
            obj.socket = msaccept(temporary_sock, 15);
            msclose(temporary_sock);
        end

        function validate(obj)
            sendVar = 'A';
            mssend(obj.socket, sendVar);

            invar = [];
            while ~strcmp(invar, 'B')
                invar = msrecv(obj.socket, 0.1);
            end

            disp('Connected.')
        end

        function set(obj, val)
            obj.data = val;
        end

        function out = get_data(obj)
            out = obj.data;
        end

        function send(obj, data)
            if nargin < 2 || isempty(data)
                data = obj.data;
            end
            mssend(obj.socket, data);
        end

        function out =  receive(obj,  timeout)
            if nargin < 2 || isempty(timeout)
                timeout = 0.5; % sec
            end

            out = msrecv(obj.socket, timeout);
        end
    end
end


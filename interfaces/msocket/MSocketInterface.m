classdef MSocketInterface < Interface
    properties
        port
        socket

        data
    end
    
    methods
        function obj = MSocketInterface(port)
            if ischar(port)
                port = str2double(port);
            end
            obj.port = port;
        end

        function connect(obj)
        end

        function handshake(obj)
        end

        function out = listen(obj)
            in = [];
            while isempty(in)
                in = msrecv(obj.socket, 0.1);
            end
            out = in;
        end

        function send(obj, data)
            mssend(obj.socket, data);
            obj.data = data; % store data
        end

        function out =  read(obj,  timeout)
            if nargin < 2 || isempty(timeout)
                timeout = 0.5; % sec
            end

            out = msrecv(obj.socket, timeout);
            obj.data = out; % store data
        end

        function out = get_data(obj)
            out = obj.data;
        end

        function flush(obj)
            invar='flush';
            while ~isempty(invar)
                invar = obj.read(0.01);
            end
        end
    end
end


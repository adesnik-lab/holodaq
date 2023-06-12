classdef MSocketInterface < Interface
    properties
        ip
        port

        socket
    end
    
    methods
        function obj = MSocketInterface(ip, socket
            obj.ip = ip;
            obj.port = socket;
        end

        function initialize(obj)
            obj.socket = msconnect(obj.ip, obj.port);
            obj.validate();
        end

        function validate(obj)
            while ~strcmp(invar,'A')
                invar=msrecv(obj.socket,.5);
            end
            sendVar= 'B';
            mssend(obj.socket, sendVar);
            disp('input from hologram computer validated');
        end

        function send(obj, cmd)
            mssend(obj.socket, cmd);
        end

        function out =  receive(obj,  timeout)
            if nargin < 2 || isempty(timeout)
                timeout = 0.5; % sec
            end

            out = msrecv(obj.socket, timeout);
        end
    end
end


classdef MSocketClient < MSocketInterface
    properties
        server_ip
    end

    methods
        function obj = MSocketClient(port, server_ip)
            obj = obj@MSocketInterface(port);
            obj.server_ip = server_ip;
        end

        function connect(obj)
            fprintf('Press any key to connect to server at %s...\n', obj.server_ip)
            pause
            obj.socket = msconnect(obj.server_ip, obj.port);
            obj.handshake();
        end

        function handshake(obj)
            out = [];
            while ~strcmp(out, 'A')
                out = obj.listen();
            end
            obj.send('B');
        end
    end
end
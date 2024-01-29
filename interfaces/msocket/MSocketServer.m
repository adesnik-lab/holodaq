classdef MSocketServer < MSocketInterface
    properties
    end

    methods
        function obj = MSocketServer(port)
            obj = obj@MSocketInterface(port);
        end            

        function connect(obj)
            temporary_sock = mslisten(obj.port);
            obj.socket = msaccept(temporary_sock, 15);
            msclose(temporary_sock);
            obj.handshake();

        end

        function handshake(obj)
            obj.send('A');

            out = [];
            while ~strcmp(out, 'B')
                out = obj.listen();
            end
        end
    end
end
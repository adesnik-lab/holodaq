classdef HoloController < Controller
    methods
        function obj = HoloController(io, name)
            obj = obj@Controller(io, name);
        end

        function run(obj)
            obj.io.send(sprintf('MsocketHolorequest2K(obj.io.socket)'))
        end
    end
end
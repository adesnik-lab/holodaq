classdef HoloController < Controller
    methods
        function obj = HoloController(io, name)
            obj = obj@Controller(io, name);
        end

        function run(obj)
            % obj.io.send('eval(sprintf(''MSocketHolorequest2K(%s.io.socket)'', inputname(1))');
            obj.io.send(join(['vars = whos;', ...
                'controllee = vars(cellfun(@(x) strcmp(x, ''Controllee''), {vars.class})).name;',...
                'eval(sprintf(''MsocketHolorequest2K(%s.io.socket)'', controllee));']))
            % obj.io.send('sprintf(''MsocketHolorequest2K(%s.io.socket),', ))
        end
    end
end
classdef PTBController < Controller
    methods
        function obj = PTBController(io, name)
            obj = obj@Controller(io, name);
        end

        function run_stimulus(obj, stimulus_name)
            % obj.io.send(sprintf('%s(''%s'', ''%s'', ''%s'')', stimulus_name, datetime('now', 'Format', 'yyMMdd'), obj.mouse, obj.epoch))
        end
    end
end
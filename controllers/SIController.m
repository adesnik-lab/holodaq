classdef SIController < Controller
    methods
        function obj = SIController(io, name)
            obj = obj@Controller(io, name);
        end

        function update(obj)
            obj.io.send('hSICtl.updateView')
        end

        function start_scanimage(obj)
            obj.io.send('scanimage');
        end

        function set_save_path(obj, path)
            obj.io.send('hSi.hScan2D.logFilepath = ''%s'';', path)
        end

        function set_filename(obj, filename)
            obj.io.send(sprintf('hSI.hScan2D.logFileStem = ''%s'';', filename))
            obj.update();
        end

        function set_external_trigger(obj, val)
            obj.io.send(sprintf('hSI.extTrigEnable = %;', val))
        end

        function set_logging(obj, val)
            obj.io.send(sprintf('hSI.loggingEntable = %d;', val))
        end


        function prepare(obj, trigger)
            if nargin < 4 || isempty(trigger)
                trigger = false;
            end
            
            obj.set_external_trigger(trigger);
            obj.set_logging(true);
            
            filename = sprintf('%s_%s_%s', datetime('now', 'Format', 'yyMMdd'), obj.mouse, obj.epoch);
            obj.set_filename(filename);
            
            % this is for my computer specifically
            obj.set_save_path()
        end

    end
    % should this be a component? idk
end
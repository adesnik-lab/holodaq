classdef SIController < Controller
    methods
        function obj = SIController(io, name)
            obj = obj@Controller(io, name);
        end

        function update(obj)
            obj.io.send('hSICtl.updateView()')
        end

        function start_scanimage(obj)
            obj.io.send('scanimage');
        end

        function set_save_path(obj, path)
            obj.io.send(sprintf('mkdir(''%s'')', path));

            if ~obj.io.read()
                fprintf('Something went wrong with creating the folder\n');
                return
            end
            obj.io.send(sprintf('hSI.hScan2D.logFilePath = ''%s'';', path));
        end

        function set_filename(obj, filename)
            obj.io.send(sprintf('hSI.hScan2D.logFileStem = ''%s'';', filename));
        end

        function set_external_trigger(obj, val)
            obj.io.send(sprintf('hSI.extTrigEnable = %d;', val))
        end

        function set_logging(obj, val)
            obj.io.send(sprintf('hSI.hChannels.loggingEnable = %d;', val))
        end


        function prepare(obj, trigger)
            if nargin < 2 || isempty(trigger)
                trigger = false;
            end
            
            obj.set_external_trigger(trigger);
            obj.set_logging(true);
            
            filename = sprintf('%s_%s_%s', datetime('now', 'Format', 'yyMMdd'), obj.mouse, obj.epoch);
            obj.set_filename(filename);
            
            % this is for my computer specifically
            base_path = 'D:';
            obj.set_save_path(fullfile(base_path, string(datetime('now', 'Format', 'yyMMdd')), obj.mouse, obj.epoch))
            obj.update();
        end

        function start(obj)
            % I'm so sorry...
            obj.io.send(join(['hSI.abort();',...
                'hSI.startLoop();',...
                'while ~strcmp(evalin(''base'', ''hSI.acqState''), ''idle'');',...
                'hSICtl.updateView(); pause(0.1);',...
                'end; disp(''exited'')']))
            
            % obj.io.send('hSI.abort()')
            % obj.io.send('hSI.startLoop()');
            % obj.io.send('stoploop');
        end

    end
    % should this be a component? idk
end
classdef DAQInput < DAQInterface
    properties (Constant)
    end

    methods
        function obj = DAQInput(dq, channel)
            obj = obj@DAQInterface(dq, channel);
        end
        
        function initialize(obj)
            ch = obj.io.addinput(obj.dev, obj.channel, obj.type);
            if strcmp(obj.type, 'voltage')
                ch.TerminalConfig = 'SingleEnded';
            end
        end

        % function out = get_daq_data(obj)
        %     persistent data; % not sure a better way to do this, this way it's shared across all intsances and not read everytime
        %     if obj.io.NumScansAvailable > 0   
        %         data = obj.io.read('all');
        %     end
        %     out = data;
        % end

        function out = get_data(obj, data)
            chn = sprintf('%s_%s', obj.dev, obj.channel);
            if any(strcmp(chn, data.Properties.VariableNames))
                out = data.(chn);
            else
                disp('wat')
            end
        end
    end
end
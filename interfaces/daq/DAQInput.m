classdef DAQInput < DAQInterface
    properties
        pulse
        sweep
    end

    methods
        function obj = DAQInput(dq, channel)
            obj = obj@DAQInterface(dq, channel);
            obj.pulse = PulseOutput(obj.sample_rate);
        end
        
        function initialize(obj)
            ch = obj.interface.addinput(obj.dev, obj.channel, obj.type);
            if strcmp(obj.type, 'voltage')
                ch.TerminalConfig = 'SingleEnded';
            end
        end
    end
end
classdef DAQInterface < Interface
    properties
        channel
        type
        sample_rate
        dev
    end

    methods
        function obj = DAQInterface(dq, channel)
            obj.interface = dq;
            dev = daqlist();
            obj.dev = dev.DeviceID(1);
            obj.channel = channel;
            obj.type = obj.derive_type();
            obj.sample_rate = obj.interface.Rate;
        end

        function type = derive_type(obj)
            switch true
                case regexp(obj.channel, 'port[0-9]/line[0-9]')
                type = 'digital';
                case regexp(obj.channel, 'a[i,o][0-9]')
                type = 'voltage';
                otherwise
                    disp('wat');
            end
        end

        function add_channel(obj, direction)
            switch direction
            case 'output'
                ch = obj.interface.addoutput(obj.dev, obj.channel, obj.type);
            case 'input'
                ch = obj.interface.addinput(obj.dev, obj.channel, obj.type);
            end
            if strcmp(obj.type, 'voltage')
                ch.TerminalConfig = 'SingleEnded';
            end
        end
        
    end
end
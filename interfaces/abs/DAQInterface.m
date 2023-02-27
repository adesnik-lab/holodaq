classdef DAQInterface < Interface
    properties
        dq
        channel
        type
    end

    methods
        function obj = DAQInterface(dq, channel)
            obj.dq = dq;
            obj.channel = channel;
            obj.type = obj.derive_type();
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
                ch = obj.dq.addoutput(obj.dq.dev, obj.channel, obj.type);
            case 'input'
                ch = obj.dq.addinput(obj.dq.dev, obj.channel, obj.type);
            end
            if strcmp(obj.type, 'voltage')
                ch.TerminalConfig = 'SingleEnded';
            end
        end
        
    end
end
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

        function initialize(obj)
        end

        function prepare(obj)
        end
    end
end
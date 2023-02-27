classdef AnalogDAQ < DAQ
properties
end
   
methods
    function obj = AnalogDAQ(dq, channel)
        obj = obj@DAQ(dq);
        obj.channel = channel;
    end

    function add_channel(obj, dir)
        switch dir
        case 'output'
            ch = obj.dq.addoutput(obj.dq.dev, obj.channel, 'voltage');
        case 'input'
            ch = obj.dq.addinput(obj.dq.dev, obj.channel, 'voltage');
        end
        ch.TerminalConfig = 'SingleEnded';
    end

end
end
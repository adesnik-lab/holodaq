classdef DigitalDAQ < DAQ
properties
end
   
methods
    function obj = DigitalDAQ(dq, channel)
        obj = obj@DAQ(dq);
        obj.channel = channel;
    end

    function initialize(obj, dir)
        switch dir
        case 'output'
            addoutput(obj.dq, obj.dq.dev, obj.channel, 'digital');
        case 'input'
            addinput(obj.dq, obj.dq.dev, obj.channel, 'digital');
        end
    end

end
end
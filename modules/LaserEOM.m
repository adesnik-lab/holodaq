classdef LaserEOM < Module
properties
    trigger
end

methods
    function obj = LaserEOM(dq, channel)
        io = DAQOutput(dq, channel);
        obj.trigger = Triggerer(io);
    end
    
    function initialize(obj)
        obj.trigger.initialize();
    end
    
    function prepare(obj)
        obj.trigger.prepare();
    end
end
end
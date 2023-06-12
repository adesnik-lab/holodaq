classdef ScanImageTrigger < Module
    properties
        trigger
    end
    
    methods
        function obj = ScanImageTrigger(dq, channel)
            io = DAQOutput(dq, channel);
            obj.trigger = Triggerer(io);
        end
        
        function initialize(obj)
            obj.trigger.initialize();
        end
        
        function prepare(obj)
        end
        
        function out = get_sweep(obj)
            out = obj.trigger.sweep;
        end
    end
end
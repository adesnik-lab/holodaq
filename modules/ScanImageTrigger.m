classdef ScanImageTrigger < Module
    properties
        trigger
        info
    end
    
    methods
        function obj = ScanImageTrigger(dq, channel)
            io = DAQOutput(dq, channel);
            obj.trigger = Triggerer(io);
            
            io = MSocketInterface();
            obj.info = Triggerer(io);
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
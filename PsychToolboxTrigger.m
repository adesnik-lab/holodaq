classdef PsychToolboxTrigger < Module
    properties
        trigger
    end
    
    methods
        function obj = PsychToolboxTrigger(dq, channel)
            io = DAQInterface(dq, channel);
            obj.trigger = Triggerer(io);
        end
        
        function initialize(obj)
            obj.trigger.initialize();
        end
        
        function prepare(obj)
           obj.trigger.prepare();
        end
        
        function out = get_sweep(obj);
            out = obj.trigger.sweep;
        end
    end
end
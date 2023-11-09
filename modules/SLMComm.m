classdef SLMComm < Module
    properties
        trigger
        flip
    end
    
    methods
        function obj = SLMComm(trigger, flip)
            obj.trigger = trigger;
            obj.flip = flip; 
        end

        function set_flip(obj, t)
            obj.trigger.set([t, 5, 5]); %standard digital trigger
        end
    end
end
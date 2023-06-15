classdef SLM < Module
    properties
        trigger
        flip
    end
    
    methods
        function obj = SLM(trigger, flip)
            obj.trigger = trigger;
            obj.flip = flip; 
        end
    end
end
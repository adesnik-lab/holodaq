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
    end
end
classdef SIComputer < Module
    properties
        trigger
        flip
    end
    
    methods
        function obj = SIComputer(trigger, flip)
            obj.trigger = trigger;
            obj.flip = flip;    
        end 
    end
end
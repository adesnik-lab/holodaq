classdef SIComputer < Module
    properties
        trigger
        flip
        controller
    end
    
    methods
        function obj = SIComputer(trigger, flip, controller)
            obj.trigger = trigger;
            obj.flip = flip;    
            obj.controller = controller;
        end 
    end
end
classdef PTBComputer < Module
    properties
        trigger
        stim_onoff
        stim_id
        controller
    end
    
    methods
        function obj = PTBComputer(trigger, stim_onoff, stim_id, controller)
            obj.trigger = trigger;
            obj.stim_onoff = stim_onoff;
            obj.stim_id = stim_id;
            obj.controller = controller;
        end
    end
end
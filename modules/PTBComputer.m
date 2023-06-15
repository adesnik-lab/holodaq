classdef PTBComputer < Module
    properties
        trigger
        stim_onoff
        stim_id
    end
    
    methods
        function obj = PTBComputer(trigger, stim_onoff, stim_id)
            obj.trigger = trigger;
            obj.stim_onoff = stim_onoff;
            obj.stim_id = stim_id;
        end
    end
end
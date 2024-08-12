classdef SLMComm < Module
    properties
        trigger
        flip
    end
    
    methods
        function obj = SLMComm(trigger, flip)
            obj.trigger = trigger;
            % obj.flip = flip; 
        end

        function set(obj, s)
            for ps = s.pulse_start
                obj.trigger.set([ps, 0.025]); %standard digital trigger
            end
        end
    end
end
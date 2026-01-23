classdef SLMComm < Module
    properties (Constant)
        pre_delay = 0.025; %s
    end
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
                obj.trigger.set([max(ps-obj.pre_delay, 0), 0.025]); %standard digital trigger, start it a touch earlier to try to get it before
            end
        end
    end
end
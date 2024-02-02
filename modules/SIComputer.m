classdef SIComputer < Module
    properties
        trigger
        flip
    end
    
    methods
        function obj = SIComputer(trigger, flip)
            obj.trigger = trigger;
            obj.flip = flip; 
            obj.controller = Controller(HolochatInterface('daq'), 'si');
        end 

        function prepare(obj)
            obj.trigger.set([1, 25]);
            obj.prepare@Module(); % how do we call superclass methods again?
        end
    end
end
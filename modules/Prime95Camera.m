classdef Prime95Camera < Module
    properties
        trigger
        flip
        wait_for_acquisition
    end
    
    methods
        function obj = Prime95Camera(trigger, flip)
            obj.trigger = trigger;
            obj.flip = flip; 
            obj.controller = Controller(HolochatInterface('daq'), 'si');
            obj.wait_for_acquisition = false;
        end 

        function wait(obj, input)
            obj.wait_for_acquisition = input;
        end

        function prepare(obj)
            obj.trigger.set([0+0.100, 0.005]); % delay for the laser shutter...
            obj.prepare@Module(); % how do we call superclass methods again?
        end

        function conclude(obj)
            if obj.wait_for_acquisition
                while obj.flip.interface.io.read().(1) < 3 % good luck
                    pause(0.1);
                end
            end
        end
    end
end
classdef LaserEOM < Module
    properties
        trigger
    end

    methods
        function obj = LaserEOM(trigger)
            obj.trigger = trigger;
        end
    end
end
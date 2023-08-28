classdef FiberTester < Module
    properties
        laser_920
        laser_1100
        si_trigger
    end
    
    methods
        function obj = FiberTester(laser_920, laser_1100, si_trigger)
            obj.laser_920 = laser_920;
            obj.laser_1100 = laser_1100;
            obj.si_trigger = si_trigger;
        end
    end
end
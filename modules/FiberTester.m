classdef FiberTester < Module
    properties
        laser_920
        laser_1100
        si_trigger
        clock
    end
    
    methods
        function obj = FiberTester(laser_920, laser_1100, si_trigger, clock)
            obj.laser_920 = laser_920;
            obj.laser_1100 = laser_1100;
            obj.si_trigger = si_trigger;
            obj.clock = clock;
        end
    end
end
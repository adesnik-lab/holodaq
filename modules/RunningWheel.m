classdef RunningWheel < Module
    properties
        wheel
    end

    methods
        function obj = RunningWheel(wheel)
            obj.wheel = wheel;
        end

        function out = save(obj)
            out = struct();
            raw_counts = obj.wheel.read();
            speed = obj.counts2speed(raw_counts);
            out.(obj.wheel.name) = obj.wheel.read();
        end

        function speed = counts2speed(obj, counts)
            speed = counts;
        end
    end
end
classdef RunningWheel < Module
    properties
        wheel
        init_ct = (2^32)/2;
        radius = 0.1; % in m
        cpr = 360; % counts per rev
    end

    methods
        function obj = RunningWheel(wheel)
            obj.wheel = wheel;
            obj.wheel.reader.enabled = true;
        end

        function out = get_data(obj)
            out = struct();
            deg = obj.wheel.reader.data * (360/obj.cpr);
            speed = movmean(obj.deg2speed(deg), 100);
            out.(obj.wheel.name(~isspace(obj.wheel.name))) = speed;
        end

        function speed = deg2speed(obj, deg)
            % convert from deg to deg/s
            angular_speed = diff(deg) * obj.wheel.interface.sample_rate; % make sure in s
            speed = angular_speed * ((2 * obj.radius * pi) / 360);
        end

        function prepare(obj)
            prepare@Module(obj); 
            ch = obj.wheel.interface.get_channel();
            ch.InitialCount = obj.init_ct;
        end
    end
end
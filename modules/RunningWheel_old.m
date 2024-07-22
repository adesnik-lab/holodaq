classdef RunningWheel < Module
    properties
        wheel
        init_ct = (2^32)/2;
        radius = 0.1524; % in m
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
            speed = movmean(obj.deg2speed(deg), 0.05 * obj.wheel.interface.sample_rate);
            out.(obj.wheel.name(~isspace(obj.wheel.name))) = speed;
            
        end

        function speed = deg2speed(obj, deg)
            % convert from deg to deg/s
            angular_speed = diff(deg) * obj.wheel.interface.sample_rate; % make sure in s
            speed = angular_speed * ((2 * obj.radius * pi) / 360);
        end

        function initialize(obj)
            initialize@Module(obj);
            ch = obj.wheel.interface.get_channel();
            % ch.InitialCount = obj.init_ct; %this costs us 0.1s per trial...    

        end

        function prepare(obj)
            prepare@Module(obj); 

        end
    end
end
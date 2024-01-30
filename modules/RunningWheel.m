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
            keyboard()
            ch = getchannel();
            ch.EncoderType = 'X1';
        end

        function out = save(obj)
            out = struct();
            deg = obj.wheel.read() * (360/obj.cpr);
            speed = obj.deg2speed(deg);
            out.(obj.wheel.name) = obj.wheel.read();
        end

        function speed = deg2speed(obj, deg)
            % convert from deg to deg/s
            keyboard()
            period = 1/dq.Rate; % find later
            angular_speed = diff(deg)/period; % make sure in s
            speed = tmp * ((2 * obj.radius * pi) / 360);
        end

        function prepare(obj)
           prepare@Module(obj); 
           % get channel
           ch = getchannel(); 
           ch.InitalCount = obj.init_ct;
        end
    end
end
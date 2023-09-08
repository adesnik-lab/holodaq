classdef ELL14 < Component
    properties (Constant = true)
        MAX_COUNT = 143360; % from thorlabs website
    end

    properties
        channel % which driver
    end

    methods

        function obj = ELL14(io, channel, name)
            obj = obj@Component(io, name);
            obj.channel = channel;
        end

        function initialize(obj)
            obj.io.initialize();
        end

        function get_position(obj)
        end

        function go_home(obj)
            obj.io.writeline(obj.cmd('ho', '0'));
        end
        
        function out = cmd(obj, input, params)
            out = sprintf('%d%s%s', obj.channel, input, params);
        end

        function moveto(obj, deg)
            count = obj.deg2count(deg);
            pos = string(dec2hex(count, 8));
            obj.io.writeline(obj.cmd('ma', pos)); % this will backlog with stuff, but its ok
            obj.wait();
        end

        function wait(obj)
            obj.io.interface.readline(); % fast read, most things come back with something so this will lock out until ready
        end

        function deg = count2deg(obj, count)
            deg = (count/obj.MAX_COUNT) * 360;
        end

        function count = deg2count(obj, deg)
            count = round((deg/360) * obj.MAX_COUNT);
        end
    end


end
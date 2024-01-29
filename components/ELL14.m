classdef ELL14 < Component
    properties (Constant = true)
        MAX_COUNT = 143360; % from thorlabs website
    end

    properties
        channel % which driver
    end

    methods

        function obj = ELL14(interface, channel, name)
            obj = obj@Component(interface, name);
            obj.channel = channel;
        end

        function initialize(obj)
            obj.interface.initialize();
        end

        function get_position(obj)
        end

        function go_home(obj)
            obj.interface.writeline(obj.cmd('ho', '0'));
        end
        
        function out = cmd(obj, input, params)
            if nargin < 3 || isempty(params)
                out = sprintf('%d%s', obj.channel, input);
            else
                out = sprintf('%d%s%s', obj.channel, input, params);
            end
        end

        function home(obj)
            obj.interface.writeline(obj.cmd('ho'));
        end

        function moveto(obj, deg)
            count = obj.deg2count(deg);
            pos = string(dec2hex(count, 8));
            obj.interface.writeline(obj.cmd('ma', pos)); % this will backlog with stuff, but its ok
            obj.wait();
        end

        function wait(obj)
            obj.interface.readline(); % fast read, most things come back with something so this will lock out until ready
        end

        function deg = count2deg(obj, count)
            deg = (count/obj.MAX_COUNT) * 360;
        end

        function count = deg2count(obj, deg)
            count = round((deg/360) * obj.MAX_COUNT);
        end
    end


end
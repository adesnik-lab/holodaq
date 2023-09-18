classdef FiberPowerControl < Module
    properties
        shutter
        hwp
        hwp_lut

        pwr = 0;
    end

    methods
        function obj = FiberPowerControl(shutter, hwp, path_to_lut)
            if nargin < 3 || isempty(path_to_lut)
                obj.hwp_lut = [];
            else
                obj.hwp_lut = importdata(path_to_lut);
            end

            obj.shutter = shutter;
            obj.hwp = hwp;
        end

        function set_power(obj, pwr)
            obj.pwr = pwr;
        end
        
        function prepare(obj)
            if ~isempty(obj.hwp_lut)
            obj.hwp.moveto(obj.pwr2deg(obj.pwr));
            end
        end

        function deg = pwr2deg(obj, pwr)
            if isempty(obj.hwp_lut)
                warning('No LUT provided, cannot convert.')
                return
            end
            deg = obj.hwp_lut.f(pwr);
        end
    end
end
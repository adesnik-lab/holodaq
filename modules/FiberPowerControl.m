classdef FiberPowerControl < Module
    properties
        shutter
        hwp
        hwp_lut
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
            obj.hwp.moveto(pwr2deg(obj.pwr));
        end

        function deg = pwr2deg(obj, pwr)
            if isempty(obj.hwp_lut)
                error('No LUT provided, cannot convert.')
            end
            deg = obj.hwp_lut(pwr);
        end
    end
end
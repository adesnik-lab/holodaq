classdef FiberPowerControl < Module
    properties
        shutter
        hwp
        hwp_lut
    end

    methods
        function obj = FiberPowerControl(shutter, hwp, path_to_lut)
            obj.shutter = shutter;
            obj.hwp = hwp;
            obj.hwp_lut = importdata(path_to_lut); % required
        end

        function set_power(obj, pwr)
            obj.pwr = pwr;
        end
        
        function prepare(obj)
            obj.hwp.moveto(pwr2deg(obj.pwr));
        end
    end
end
classdef FiberPower950 < FiberPowerControl
    properties
    end

    methods
        function obj = FiberPower950(shutter, hwp, path_to_lut)
            obj = obj@FiberPowerControl(shutter, hwp, path_to_lut);
        end
    end
end
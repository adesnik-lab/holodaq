classdef HoloComputer < Module
    properties
        controller
    end

    methods
        function obj = HoloComputer(controller)
            obj.controller = controller;
        end
    end
end
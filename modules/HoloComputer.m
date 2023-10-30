classdef HoloComputer < Module
    properties
        controller

        sequence
    end

    methods
        function obj = HoloComputer(controller)
            if nargin < 0
                controller = [];
            end
            obj.controller = controller;
        end

        function set_sequence(obj, sequence)
            obj.sequence = sequence;
        end

        function prepare(obj)
            obj.controller.io.send(obj.sequence);
            obj.prepare@Module();
        end
    end
end
classdef Patch < Module
    properties
        control
        patch_input
    end

    methods

        function obj = Patch(control, patch_input)
            obj.control = control;
            obj.patch_input = patch_input;
            obj.patch_input.reader.enabled = true;
        end

        function out = get_data(obj)
            out = struct();
            out.(obj.patch_input.name(~isspace(obj.patch_input.name))) = obj.patch_input.reader.data;
        end
    end
end
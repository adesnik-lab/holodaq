classdef PatchReader < Module
    properties
        patcher
    end

    methods
        function obj = PatchReader(patch_input)
            obj.patcher = patch_input;
            obj.patcher.reader.enable();
        end

        function out = get_data(obj)
            out = obj.patcher.reader.data;
        end
    end
end
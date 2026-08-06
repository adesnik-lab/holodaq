classdef FakeUserFunctions < handle
    %FAKEUSERFUNCTIONS Stand-in for hSI.hUserFunctions, for SIReceiver tests.
    %   Holds a userFunctionsCfg struct array with UserFcnName/Enable, matching what
    %   set_user_function and enabled_user_functions read. Built as a struct array
    %   rather than objects because that is the shape ScanImage exposes and the shape
    %   the arrayfun/indexing in those methods relies on.
    %
    %   See also: test_si_user_functions

    properties
        userFunctionsCfg
    end

    methods
        function obj = FakeUserFunctions(names, enabled)
            if nargin < 2, enabled = false(size(names)); end
            for i = numel(names):-1:1
                obj.userFunctionsCfg(i).UserFcnName = names{i};
                obj.userFunctionsCfg(i).Enable = enabled(i);
            end
        end

        function tf = is_enabled(obj, name)
            idx = strcmp({obj.userFunctionsCfg.UserFcnName}, name);
            tf = any(idx) && any([obj.userFunctionsCfg(idx).Enable]);
        end
    end
end

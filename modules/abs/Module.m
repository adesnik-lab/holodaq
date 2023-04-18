classdef Module < dynamicprops
    properties
%         submodules
        enabled = true;
    end
    
    methods
        function obj = Module()
        end
        function initialize(obj)
        end
        
        function out = prepare(obj)
        end
        
        function add_submodule(obj, submodule)
            obj.submodules.add(submodule);
        end
        
        function out = extract(obj, query)
            props = properties(obj);
            is_queried = cellfun(@(x) isa(obj.(x), query), props);
            if ~any(is_queried)
                out = [];
            else
                out = obj.(props{is_queried});
            end
        end
        
        function out = contains(obj, query)
            props = properties(obj);
            is_queried = cellfun(@(x) isa(obj.(x), query), props);
            if ~any(is_queried)
                out = false;
            else 
                out = true;
            end
        end
    end
end
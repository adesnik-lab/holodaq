classdef Module < dynamicprops
    properties
%         submodules
        enabled = true;
    end
    
    methods
        function obj = Module()
        end

        function initialize(obj)
            components = obj.extract('Component');
            for c = components
                c.initialize();
            end
        end
        
        function out = prepare(obj)
        end

        function save(obj)
        end
        
        % function add_submodule(obj, submodule)
        %     obj.submodules.add(submodule);
        % end
        
        function out = extract(obj, query)
            props = properties(obj);
            is_queried = cellfun(@(x) isa(obj.(x), query), props);
            if ~any(is_queried)
                out = [];
            else
                ct = 1;
                for q = find(is_queried)'
                    out(ct) = obj.(props{q});
                    ct =ct + 1;
                end
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
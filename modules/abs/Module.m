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

        function store_trial_data(obj)
            % check if a saver exists and why it wasn't saved?
            disp('Did you have trial data for this noe?')
        end
        
        % function add_submodule(obj, submodule)
        %     obj.submodules.add(submodule);
        % end
        
        function out = get_objs(obj)
            props = properties(obj);
            is_obj = cellfun(@(x) isobject(x), props);
            if ~any(is_obj)
                return;
            end
            out = cat(2,  obj.get_objs, obj.(props{is_obj})); % will this work?
        end

        function out = extract(obj, query)
            all_objs = obj.get_objs();
            all_objs(~isa(all_objs, query)) = [];
            out = all_objs;
        end

        function out = extract2(obj, query)
            % this needs to be recursive?
            props = properties(obj);
            is_queried = cellfun(@(x) isa(obj.(x), query), props);
            if ~any(is_queried)
                out = [];
            else
                ct = 1;
                for q = find(is_queried)'
                    out(ct) = obj.(props{q});
                    ct = ct + 1;
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
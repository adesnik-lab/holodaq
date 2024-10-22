classdef Module < matlab.mixin.Heterogeneous & handle
    properties
        enabled = true;
        controller
    end
    
    methods
        function obj = Module()
        end

        function initialize(obj)
            for c = obj.extract('Component')
                c.initialize();
            end
        end
        
        function prepare(obj)
            for c = obj.extract('Component')
                c.prepare();
            end
        end

        function conclude(obj)
        end

        function get_data(obj)
        end
        
        function out = extract(obj, query)
            % recursively find all objects, then query
            all_objs = obj.get_objs(obj, []);
            is_queried = cellfun(@(x) isa(x, query), all_objs);
            out = [all_objs{is_queried}];
        end

        function all_objs = get_objs(obj, target, all_objs)
            if isa(target, 'daq.interfaces.DataAcquisition') %prevents it from going too far
                return; % break
            end

            props = properties(target);
            is_obj = cellfun(@(x) isobject(target.(x)), props);
            for o = find(is_obj)'
                all_objs = cat(1, all_objs, {target.(props{o})});
                all_objs = obj.get_objs(target.(props{o}), all_objs);
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
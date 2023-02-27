classdef Module < dynamicprops
    properties
%         submodules
        enabled = true;
    end
    
    methods
        function obj = Module()
        end
        
%         function out = get.trigger(obj)
%             modules = properties(obj.submodules);
%             is_trigger = cellfun(@(x) isa(obj.submodules.(x), 'Triggerer'), modules);
%             if sum(is_trigger) > 1
%                 error('More than one Triggerer present?')
%             end
%             
%             out = obj.submodules.(modules{is_trigger});
%         end
%         
        function initialize(obj)
            %             obj.controller.initialize();
%             obj.submodules.call('initialize');
        end
        
        function out = prepare(obj)
%             out = obj.controller.prepare();
%             out = obj.submodules.call('prepare');
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
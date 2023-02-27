classdef ModuleManager < dynamicprops
    properties
    end

    methods
        function obj = ModuleManager();
        end

        function add(obj, module)
            try
                obj.addprop(class(module));
            catch ME
                if strcmp(ME.identifier, 'MATLAB:class:PropertyInUse')
                    warning('Module %s already exists.\n', class(module));
                    return
                else
                    rethrow(ME);
                end
            end
            obj.(class(module)) = module;
        end

        function out = call(obj, function_name, varargin)
            out = cell(1, length(properties(obj)));
            ct = 1;
            for m = properties(obj)'
                % FIX THIS FOR NO OUTPUT ARGUMENTS?
                try
                    out{ct} = feval(function_name, obj.(m{:}).controller, varargin{:});
                catch ME
                    if strcmp(ME.message, 'Too many output arguments.')
                        feval(function_name, obj.(m{:}).controller, varargin{:});
                    else
                        rethrow(ME)
                    end
                end
                ct = ct + 1;
            end
        end
        
        function out = get_outputs(obj)
            props = properties(obj);
            is_output = cellfun(@(x) strcmp(obj.(x).controller.direction, 'output'), props);
            if ~any(is_output)
                fprintf('No output modules.\n')
                return
            end
            
            out = ModuleManager();
            for i = find(is_output)'
                out.add(obj.(props{i}));
            end
        end
        
        function out = get_inputs(obj)
            props = properties(obj);
            is_input = cellfun(@(x) strcmp(obj.(x).controller.direction, 'input'), props);
            if ~any(is_input)
                fprintf('No input modules.\n')
                return
            end
            
            out = ModuleManager();  
            for i = find(is_input)'
                out.add(obj.(props{i}));
            end
        end
        
        function out = get(obj, query)
            props = properties(obj);
            is_queried = cellfun(@(x) isa(obj.(x), query), props);
            if ~all(is_queried)
                fprintf('No modules found with query: %s\n', query)
                return
            end
            
            out = ModuleManager();
            for i = find(is_queried)'
                out.add(obj.(props{i}));
            end
        end
    end
end
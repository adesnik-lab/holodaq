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
                        out{ct} = feval(function_name, obj.(m{:}), varargin{:});
                    catch ME
                        if strcmp(ME.message, 'Too many output arguments.')
                            feval(function_name, obj.(m{:}), varargin{:});
                        else
                            rethrow(ME)
                        end
                    end
                    ct = ct + 1;
                end
                out = cat(2, out{:});
         end

        
        function out = extract(obj, query)
            out = obj.call('extract', query);
        end
        
        function out = contains(obj, query)
            has_query = obj.call('contains', query);
            
            props = properties(obj);
            out = ModuleManager();
            for i = find(has_query)
                out.add(obj.(props{i}));
            end
        end
    end
end
classdef ModuleManager < dynamicprops
    properties
    end

    methods
        function obj = ModuleManager();
        end

        function module_name = check_for_duplicate(obj, module_name)
            persistent ct
            if isempty(ct)
                ct = 0;
            end
            is_duplicate = any(cellfun(@(x) strcmp(module_name, x), properties(obj)));
            if ~is_duplicate
                return
            end
            module_name = sprintf('%s_%d', class(module), ct + 1);
            module_name = obj.check_for_duplicate(module_name)
        end
        
        function add(obj, module)
            module_name = obj.check_for_duplicate(class(module));
            obj.addprop(module_name);
            obj.(module_name) = module;
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
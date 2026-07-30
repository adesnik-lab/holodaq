classdef ModuleManager < dynamicprops
    properties
    end

    methods
        function obj = ModuleManager();
        end

        function module_name = check_for_duplicate(obj, module_name)
            existing = properties(obj);
            if ~any(strcmp(module_name, existing))
                return
            end
            % strip any existing numeric suffix back to the base class name
            base = module_name;
            us = strfind(base, '_');
            if ~isempty(us)
                base(us(1):end) = [];
            end
            % find the lowest free suffix (base_1, base_2, ...)
            k = 1;
            while any(strcmp(sprintf('%s_%d', base, k), existing))
                k = k + 1;
            end
            module_name = sprintf('%s_%d', base, k);
        end
        
        function add(obj, module, name)
            %ADD Register a module, optionally under an EXPLICIT key.
            %   add(m)        key it by class(m), auto-suffixing '_1', '_2' for
            %                 repeats. What every caller did before, and still
            %                 does: the inline experiment runners and both
            %                 patch_experiment copies rely on it.
            %   add(m, name)  key it verbatim as `name`.
            %
            %   Why the explicit form exists: keying by class means the FIRST
            %   instance added gets the bare class name and the second gets '_1',
            %   so with two lasers `modules.LaserPowerControl` was whichever one
            %   happened to be added first. Which physical laser a caller reached
            %   depended on add ORDER, silently. An explicit key is a claim about
            %   WHICH device, so a collision is refused rather than suffixed --
            %   auto-suffixing a claimed name is the original bug in miniature.
            if nargin < 3 || isempty(name)
                module_name = obj.check_for_duplicate(class(module));
            else
                module_name = char(name);
                assert(isvarname(module_name), 'ModuleManager:badKey', ...
                    'Module key ''%s'' is not a valid MATLAB identifier.', module_name);
                assert(~any(strcmp(module_name, properties(obj))), ...
                    'ModuleManager:duplicateKey', ...
                    ['A module is already registered as ''%s''. Explicit keys are ' ...
                     'not suffixed:\nthe caller asked for a specific device, so ' ...
                     'silently renaming it to ''%s_1''\nwould hand them a ' ...
                     'different one.'], module_name, module_name);
            end
            obj.addprop(module_name);
            obj.(module_name) = module;
        end

        function tf = has(obj, name)
            %HAS Is a module registered under this key?
            tf = any(strcmp(char(name), properties(obj)));
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
                out(cellfun(@isempty, out)) = [];
                if ~isempty(out)
                if all(cellfun(@isstruct, out))
                    out = obj.mergestructs(out);
                else
                    out = cat(2, out{:});
                end
                end
         end

         function out = mergestructs(obj, in)
             out = struct();
             for s = in
                 for f = fieldnames(s{:})
                    out.(f{:}) = s{:}.(f{:});
                 end
             end
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
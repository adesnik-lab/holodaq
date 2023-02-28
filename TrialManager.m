classdef TrialManager < handle

    properties
        modules
        dq

        sweep
    end

    methods
        function obj = TrialManager(dq)
            obj.dq = dq;
            obj.modules = ModuleManager();
        end
        
        function initialize(obj)
            obj.modules.call('initialize');
        end

        function set_trial_length(obj, trial_length)
            for t = obj.modules.extract('Triggerer')
                t.set_trial_length(trial_length);
            end
        end
        
        function prepare(obj)
            for t = obj.modules.extract('Triggerer')
                t.generate_sweep();
                obj.sweep = [obj.sweep; t.get_sweep()];
            end
            
%             for r = obj.module.extract('Readers')
%                 r.prepare_to_read();
%             end
        end

        function out = start(obj)
    
        end

        function show(obj)
            triggers = obj.modules.contains('Triggerer');
            module_names = properties(triggers);
            n_modules = length(module_names);
            figure;
            for o = 1:n_modules
                subplot(n_modules, 1, o)
                plot(obj.sweep(o, :));
                ylabel(module_names{o})
            end
        end  
    end
end
classdef TrialManager < handle

    properties
        modules
        dq

        sweep
        in
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
                sweep = t.generate_sweep();
                obj.sweep = cat(2, obj.sweep, sweep);
            end
        end

        function out = start_trial(obj)
            disp('started trial')
            try % hacky solution for not having any input channels
                obj.in = obj.dq.readwrite(obj.sweep);
            catch
                obj.dq.write(obj.sweep);
            end
        end

        function end_trial(obj)
            % cleanup and maintenance after a trial ends
            % separate the data
            
            obj.sweep = [];
        end

        function show(obj)
            triggers = obj.modules.contains('Triggerer');
            module_names = properties(triggers);
            n_modules = length(module_names);
            figure;
            for o = 1:n_modules
                subplot(n_modules, 1, o)
                plot(obj.sweep(:, o));
                ylabel(module_names{o})
            end
        end  
    end
end
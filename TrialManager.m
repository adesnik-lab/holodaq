classdef TrialManager < handle

    properties
        modules
        dq
        trial_length

        sweep
        out
    end

    methods
        function obj = TrialManager(dq)
            obj.dq = dq;
            obj.modules = ModuleManager();
        end
        
        function initialize(obj)
            obj.modules.call('initialize');
        end


        function prepare(obj)
            % set trial length here
            % generate sweeps
            % prepare msockets
            % obj.modules.call('prepare');
            for t = obj.modules.extract('Triggerer')
                switch class(t.io)
                    case 'DAQOutput'
                        t.io.set_trial_length(obj.trial_length);
                        obj.sweep = cat(2, obj.sweep, t.io.generate_sweep());
                    case 'MSocketInterface'
                end
            end
        end

        function out = start_trial(obj)
            % send EVERYTHING
            disp('started trial')
            for t = obj.modules.extract('Triggerer') % let's track how long this takes...
                if isa(t.io, 'MSocketInterface')
                    t.io.send();
                end
            end
            try % hacky solution for not having any input channels
                obj.out = obj.dq.readwrite(obj.sweep);
            catch
                obj.dq.write(obj.sweep);
            end
            fprintf('expected length: %0.5f\n', size(obj.sweep, 1)/obj.dq.Rate)
        end

        function end_trial(obj)
            % read all data in
            for r = obj.modules.extract('Reader')
                chn = sprintf('%s_%s', r.io.dev, r.io.channel);
                r.data = obj.out.(chn);
            end
            obj.modules.call('save'); % save it
            obj.out = [];
            obj.sweep = [];
        end

        function set_trial_length(obj, trial_length)
            obj.trial_length = trial_length; %
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
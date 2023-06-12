classdef TrialManager < handle

    properties
        modules
        dq
        trial_length

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
                    case 'Msocket'
                end
            end
        end

        function out = start_trial(obj)
            % send EVERYTHING
            disp('started trial')
            try % hacky solution for not having any input channels
                out = obj.dq.readwrite(obj.sweep);
            catch
                obj.dq.write(obj.sweep);
            end
        end

        function end_trial(obj)
            % cleanup and maintenance after a trial ends
            % separate the data
            
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
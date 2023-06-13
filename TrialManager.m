classdef TrialManager < handle

    properties
        modules
        dq
        trial_length
        saver
        save_path
        sweep
    end

    methods
        function obj = TrialManager(dq)
            obj.dq = dq;
            obj.modules = ModuleManager();
        end
        
        function initialize(obj)
            obj.modules.call('initialize');
            % set save paths on all savers
            emptystruct = struct;

            for s = obj.modules.extract('Saver')
                s.set_save_path(obj.save_path);
            end
        end
        
        function do_stuff(obj)
            for s = obj.modules.extract('Saver')
                s.write();
            end
        end

        function prepare(obj)
            for t = obj.modules.extract('Triggerer')
                switch class(t.io)
                    case 'DAQOutput'
                        t.io.set_trial_length(obj.trial_length);
                        obj.sweep = cat(2, obj.sweep, t.io.generate_sweep());
                    case 'MSocketInterface'
                end
            end
            obj.dq.start();
        end

        function start_trial(obj)
            disp('started trial')

            obj.dq.write(obj.sweep); % because this is now running in background, we can call other stuff
            for t = obj.modules.extract('Triggerer') % let's track how long this takes...
                if isa(t.io, 'MSocketInterface')
                    t.io.send();
                end
            end    
            obj.sweep = [];
        end

        function end_trial(obj)
            % read all data in
            obj.wait()

            out = obj.dq.read('all');
            for r = obj.modules.extract('Reader')
                chn = sprintf('%s_%s', r.io.dev, r.io.channel);
                r.data = out.(chn);
            end
            obj.modules.call('save'); % save it

            obj.do_stuff();
        end
    
        function set_save_path(obj, save_path)
            obj.save_path = save_path;
        end

        function set_trial_length(obj, trial_length)
            obj.trial_length = trial_length; %
        end
        
        function wait(obj)
            while obj.dq.Running()
                drawnow();
            end
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
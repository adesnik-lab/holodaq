classdef TrialManager < handle

    properties
        modules
        dq
        trial_length
        saver
        save_path
        
        stream_to_disk
    end

    methods
        function obj = TrialManager(dq)
            obj.dq = dq;
            obj.modules = ModuleManager();
            obj.stream_to_disk = true;
            % obj.params.stream = params.stream;
        end
        
        function initialize(obj)
            obj.modules.call('initialize');
            obj.saver = Saver();
            obj.saver.set_save_path(obj.save_path);
        end
    
        function prepare(obj)
            sweep = [];
            for o = obj.modules.extract('Output')
                switch class(o.io)
                    case 'DAQOutput'
                        o.io.set_trial_length(obj.trial_length);
                        sweep = cat(2, sweep, o.io.generate_sweep());
                    case 'MSocketInterface'
                        % o.set_data*('heuhcoreuh')
                end
            end
            obj.dq.preload(sweep);
        end

        function start_trial(obj)
            disp('started trial')
            for t = obj.modules.extract('Output') % let's track how long this takes...
                if isa(t.io, 'MSocketInterface')
                    t.io.send();
                end
            end

            obj.dq.start(); % because this is now running in background, we can call other stuff
 
        end

        function end_trial(obj)
            % read all data in
            obj.wait()
            obj.dq.stop();
            disp('ended trial')
            
            obj.transfer_data();
            obj.save_data();

            % cleanup?
            obj.cleanup();
        end

        function cleanup(obj)
            for p = obj.modules.extract('PulseOutput')
                p.flush();
            end
        end

        function transfer_data(obj)
            for r = obj.modules.extract('Reader')
                r.read();
            end
        end

        function save_data(obj)
            exp = struct();
            for c = obj.modules.extract('Component')
                field_name = c.name;
                field_name(isspace(field_name)) = [];
                exp.(field_name) = c.reader.data;
            end
            obj.saver.store(exp);

            if obj.stream_to_disk
                obj.saver.save('append');
            end
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
classdef TrialManager < handle

    properties
        modules
        dq
        trial_length        
    end

    methods
        function obj = TrialManager(dq)
            obj.dq = dq;
            obj.modules = ModuleManager();
        end
        
        function initialize(obj)
            obj.modules.call('initialize');
        end

        function out = run_trial(obj, time)
            if nargin < 2 || isempty(time)
                time = false;
            end

            obj.prepare(time);
            obj.start_trial(time);
            out = obj.end_trial(time);
        end
    
        function prepare(obj, time)
            if nargin < 2 || isempty(time)
                time = 0;
            end
            if time
                tic;
            end
            sweep = [];
            obj.modules.call('prepare'); % remove if breaks

            % prepare daq sweeps
            % for o = obj.modules.extract('Output') % can we directly get DAQOutputs?
            %     switch class(o.interface)
            %         case 'DAQOutput'
            %             o.interface.set_trial_length(obj.trial_length);
            %             sweep = cat(2, sweep, o.interface.generate_sweep());
            %     end
            % end
            % try this
            for o = obj.modules.extract('DAQOutput')
                o.set_trial_length(obj.trial_length);
                sweep = cat(2, sweep, o.generate_sweep());
            end
            obj.dq.preload(sweep);
            % obj.dq.start();
            if time
                fprintf('Preparing took %0.02fs\n', toc)
            end
        end

        function start_trial(obj, time)
            if nargin < 2 || isempty(time)
                time = false;
            end
            % cleanup_obj = onCleanup(@obj.cleanup); % so pretty much anywhere we'll catch this
            % disp('started trial')
            % for t = obj.modules.extract('Controller') % let's track how long this takes...
            %     if isa(t.io, 'MSocketInterface') && ~isempty(t.data)
            %         t.io.send(t.data);
            %     end
            % end
            if time
                tic
            end
            % obj.dq.write(obj.sweep);
            obj.dq.start(); % because this is now running in background, we can call other stuff
            if time
                fprintf('Starting took %0.02fs\n', toc)
            end
        end

        function out = end_trial(obj, time)
            if nargin < 2 || isempty(time)
                time = false;
            end
            cleanup_obj = onCleanup(@obj.cleanup);
            % read all data in
            obj.wait()
            if time
                tic
            end
            obj.dq.stop();
            
            out = obj.transfer_data();
            % obj.save_data2();

            % cleanup?
            obj.cleanup();
            if time
                fprintf('Finishing took %0.02fs\n', toc)
            end
        end

        % function finish(obj)
        %     obj.saver.save('all');
        % end

        function cleanup(obj)
            for p = obj.modules.extract('Generator')
                p.flush();
            end
            obj.dq.stop();
            obj.dq.flush();
        end

        function out = transfer_data(obj)
            for r = obj.modules.extract('Reader')
                r.read();
            end
            out = obj.modules.call('get_data');
        end

        % function save_data2(obj)
        %     exp = obj.modules.call('get_data');
        %     obj.saver.store(exp)
        %     % if obj.stream_to_disk
        %     %     obj.saver.save('append')
        %     % end
        % end

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
        
        function set_mouse(obj, mouse)
            for c = obj.modules.extract('Controller')
                c.mouse = mouse;
            end
        end

        function set_epoch(obj, epoch)
            for c = obj.modules.extract('Controller')
                c.epoch = epoch;
            end
        end

        function set_save_path(obj, save_path)
            obj.save_path = save_path;
        end

        function set_trial_length(obj, trial_length)
            obj.trial_length = trial_length;
        end
        
        function wait(obj)
            while obj.dq.NumScansQueued > 0
                drawnow();
            end
        end
    
        function cleanup_test(obj)
            disp('Press any key to cleanup and continue (ctrl-c to skip cleanup)...')

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
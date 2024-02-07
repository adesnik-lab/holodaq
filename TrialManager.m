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
                t = tic;
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
            % obj.sweep = sweep;
            obj.dq.preload(sweep);
            % obj.dq.start();
            if time
                fprintf('Preparing took %0.02fs\n', toc(t))
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
            %     endo
            
            % end
            if time
                t = tic;
            end
            % obj.dq.write(obj.sweep);
            obj.dq.start(); % because this is now running in background, we can call other stuff
            % obj.dq.readwrite(obj.sweep);
            if time
                fprintf('Starting took %0.02fs\n', toc(t))
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
                t = tic;
            end
            % obj.dq.stop();
            
            out = obj.transfer_data();
            % obj.save_data2();

            % cleanup?
            obj.cleanup();
            if time
                fprintf('Finishing took %0.02fs\n', toc(t))
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

        function set_trial_length(obj, trial_length)
            obj.trial_length = trial_length;
        end
        
        function wait(obj)
            while obj.dq.NumScansQueued > 0
                % disp(obj.dq.NumScansQueued)
                drawnow();
            end
        end
    
        function cleanup_test(obj)
            disp('Press any key to cleanup and continue (ctrl-c to skip cleanup)...')

        end
    end
end
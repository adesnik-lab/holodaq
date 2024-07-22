classdef TrialManager < handle

    properties
        modules
        dq
        trial_length
        sweep

        trial_timer
        trial_data
    end

    methods
        function obj = TrialManager(dq)
            obj.dq = dq;
            obj.modules = ModuleManager();
        end

        function initialize(obj)
            obj.modules.call('initialize');
            obj.dq.start();
            % obj.dq.start("continuous");
            % obj.dq.ScansAvailableFcn = @obj.transfer_data;
            % obj.dq.ScansAvailableFcnCount = 60000;
            obj.dq.write(zeros([5, length(obj.modules.extract('DAQOutput'))]));
            % obj.dq.read(0.01); % blip
            % obj.trial_timer = timer('ExecutionMode', 'FixedRate',...
            %     'BusyMode', 'drop',...
            %     'Period', 1/2,...
            %     'TimerFcn', @(~,~)obj.wait);
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

            % set all trial lengtsh first
            for o = obj.modules.extract('DAQOutput')
                o.set_trial_length(obj.trial_length);
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
                % o.set_trial_length(obj.trial_length);
                sweep = cat(2, sweep, o.generate_sweep());
            end
            obj.sweep = sweep;
            obj.dq.flush();
            % clear out the DAQ by reading it
            % obj.dq.read(obj.dq.NumScansAvailable);
            % obj.dq.preload(sweep);
            if time
                fprintf('Preparing took %0.02fs\n', toc(t))
            end
        end

        function start_trial(obj, time)
            if nargin < 2 || isempty(time)
                time = false;
            end

            if time
                t = tic;
            end
            obj.trial_data = obj.dq.readwrite(obj.sweep);
            % obj.dq.start(); % because this is now running in background, we can call other stuff
            if time
                fprintf('Starting took %0.02fs\n', toc(t))
            end
        end

        function out = end_trial(obj, time)
            if nargin < 2 || isempty(time)
                time = false;
            end
            % cleanup_obj = onCleanup(@obj.cleanup);
            % wait for daq here...
            
            
            waitfor(obj.dq, 'Running', 0); % wait until  daq is finished
            % read all data in
            if time
                t = tic;
            end
            
            out = obj.transfer_data();

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
            % obj.dq.stop();
            obj.dq.flush();
        end

        function out = transfer_data(obj)
            for r = obj.modules.extract('Reader')
                r.read(obj.trial_data);
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

    end
end

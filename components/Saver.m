classdef Saver < handle
    properties (Constant = true)
        base_path = 'K://KKS//stim-data'
    end

    properties
        data = [];


        matfile_handle

        mouse char
        epoch double
        experiment char

        stream_to_disk = false;
    end

    methods
        function obj = Saver(mouse, epoch, experiment)
            obj.mouse = mouse;
            obj.epoch = epoch;
            obj.experiment = experiment;
            obj.set_save_path(obj.derive_save_path())
        end

        function out = derive_save_path(obj)
            out = fullfile(obj.base_path, obj.date, sprintf('%s_%s_%d%s.mat', obj.date, obj.mouse, obj.epoch, obj.experiment));
        end

        function set_save_path(obj, save_path)
            if exist(save_path, 'file')
                while true
                    switch input('Save file already exists, overwrite? (y/n):', 's')
                        case 'y'
                            break
                        case 'n'
                            error('Did you forget to change your epoch?')
                        otherwise
                            continue
                    end
                end
            end
            fprintf('Saving data in ''%s''\n', save_path);
            if ~exist(fileparts(save_path), 'dir')
                mkdir(fileparts(save_path))
            end
            obj.matfile_handle = matfile(save_path, 'Writable', true);
        end

        function add(obj, data, name)
            obj.matfile_handle.(name) = data;
        end

        function set_mouse(obj, mouse)
            obj.mouse = mouse;
        end

        function set_epoch(obj, epoch)
            obj.epoch = epoch;
        end

        function set_experiment(obj, experiment)
            obj.experiment = experiment;
        end

        function out = date(obj)
            out = string(datetime('today', 'Format', 'yyMMdd'));
        end

        function store(obj, data)
            obj.data = cat(2, obj.data, data); % append the current data present in the reader
        end

        function view(obj)
            n_trials = length(obj.data);
            trial_lengths = cellfun(@length, obj.data);
            for ii = 1:n_trials
                subplot(n_trials, 1, ii)
                plot(obj.data{ii})
                xlim([0, max(trial_lengths)]);
                title(sprintf('Trial #%d', ii))
            end
        end

        function save(obj, flag)
            % also includes formatting
            switch flag
                case 'append'
                    % mess wit hthis, how can we grow a structure?
                    try
                        obj.matfile_handle.data(end+1, 1) = obj.data(end); % is this dangerous?
                    catch
                        obj.matfile_handle.data = obj.data(end); % assume first run?
                    end
                case 'all'
                    obj.matfile_handle.data = obj.data; % all
            end
        end

        function reset(obj)
            disp('Press any key to reset Saver (clears all data)...')
            pause
            obj.data = [];
        end
    end
end
classdef Saver < handle
    
    properties
        data = [];

        save_path
        matfile_handle

        description
        name
    end
    
    methods
        function obj = Saver(save_path)
            obj.set_save_path(save_path);
            % can we get the object name here?
        end

        function set_save_path(obj, save_path)
            obj.save_path = save_path;
            % check exists
            if isfile(obj.save_path)
                fprintf('Warning: Data save file already exists, appending...')
            end
            obj.matfile_handle = matfile(obj.save_path, 'Writable', true);
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
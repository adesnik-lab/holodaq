classdef Saver < handle
    
    properties
        data = []
        % trial_count

        save_path
        matfile_handle

        description
        name
    end
    
    methods
        function obj = Saver(description)
            obj.description = description;
            % can we get the object name here?
        end

        function set_save_path(obj, save_path)
            obj.save_path = save_path;
            obj.matfile_handle = matfile(obj.save_path, 'Writable', true);
        end

        function store(obj, data)
            obj.data = cat(2, obj.data, {data}); % append the current data present in the reader
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
                    obj.matfile_handle.ExpStruct(end+1, 1).(obj.description) = obj.data{end}; % is this dangerous?
                case 'all'
                    obj.matfile_handle.ExpStruct.(obj.description) = obj.data; % all
            end
        end
    end
end
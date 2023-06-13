classdef Saver < Component
    
    properties
        data = []
        % trial_count

        save_path
        matfile_handle

        reader
        name
    end
    
    methods
        function obj = Saver(reader, name)
            obj.reader = reader;
            obj.name = name;
        end
        
        function initialize(obj)
        end
        
        function set_save_path(obj, save_path)
            obj.save_path = save_path;
            obj.matfile_handle = matfile(obj.save_path, 'Writable', true);
        end

        function add_data(obj, data)
            % obj.data{obj.trial_count} = data;
            % obj.trial_count = obj.trial_count + 1;
            obj.data = cat(2, obj.data, {data}); % append
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

        function write(obj)
            % if nargin < 2 || isempty(previous)
            %     previous = false;
            % end
            % % saves the PREVIOUS trial
            % save_ctr = obj.trial_count;
            % if previous
            %     save_ctr = save_ctr-1;
            % end
            % 
            % if save_ctr == 0
            %     return
            % end
            ctr = size(obj.data, 2);
            obj.matfile_handle.(obj.name)(ctr, 1) = obj.data(ctr);
        end
    end
end


classdef Saver < handle
    
    properties
        data

        trial_count
    end
    
    methods
        function obj = Saver()
            obj.trial_count = 1;
        end
        
        function initialize(obj)
        end
        
        function add_data(obj, data)
            obj.data{obj.trial_count} = data;
            obj.trial_count = obj.trial_count + 1;
        end
            
        function view(obj)
            n_trials = length(obj.data);
            for ii = 1:n_trials
                subplot(n_trials, 1, ii)
                plot(obj.data{ii})
                title(sprintf('Trial #%d', ii))
            end
        end
    end
end


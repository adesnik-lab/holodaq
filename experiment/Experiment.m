classdef Experiment < handle
    properties
        trial_manager
    end

    methods
        function Experiment(trial_manager)
            obj.trial_manager = trial_manager;
        end
    end
end
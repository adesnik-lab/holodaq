classdef TrialManager < handle

    properties
        modules
        dq

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

        function set_trial_length(obj, trial_length)
            output_modules = obj.modules.get_outputs();
            output_modules.call('set_trial_length', trial_length);
        end
        
        function prepare(obj)
            output_modules = obj.modules.get_outputs();
            outputs = output_modules.call('prepare');
         
            obj.sweep = cat(1, outputs{:});
        end

        function out = start(obj)

        end

        function show(obj)
            imagesc(obj.sweep)
        end



    end
end
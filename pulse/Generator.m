classdef Generator < handle
    properties
        sample_rate
        sweep_length
        
    end

    methods
       function obj = Generator(sample_rate)
        obj.sample_rate = sample_rate;
        end

        function samples = to_samples(obj, s)
            samples = round(s * obj.sample_rate);
        end

        function set_trial_length(obj, trial_length)
            obj.sweep_length = trial_length;
        end

        function flush(obj)
        end

        function generate(obj)
        end

        function set(obj)
        end

    end

end

classdef SweepGenerator < Generator
    properties
        sweep
    end

    methods
        function obj = SweepGenerator(sample_rate)
            obj = obj@Generator(sample_rate);
        end

        function set(obj, sweep)
            if length(sweep) ~= obj.to_samples(obj.sweep_length)
                warning('Provided sweep is incorrect length (%d samples)', obj.to_samples(obj.sweep_length))
                return
            end
            obj.sweep = sweep; % need some kind of validation here I think...
        end

        function flush(obj)
            obj.sweep = [];
        end

        function out = generate(obj)
            if isempty(obj.sweep)
                out = zeros(obj.to_samples(obj.sweep_length), 1);
            else
                out = obj.sweep;
            end
        end

    end
end
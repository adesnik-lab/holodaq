classdef PulseGenerator < Generator
    properties
        pulse_starts
        pulse_lengths
    end

    properties (GetAccess = private)
        default_trig_length = 5; % ms
    end

    methods
        function obj = PulseGenerator(sample_rate)
            obj = obj@Generator(sample_rate);
        end

        function sweep = generate(obj)
            sweep = zeros(obj.to_samples(obj.sweep_length), 1);
            sweep = add_pulse(sweep);
        end
    end

    methods
        function sweep = add_pulse(obj, sweep)
            if any((obj.pulse_starts + obj.pulse_lengths) > obj.sweep_length)
                error('Trigger longer than sweep length')
            end
            for o = 1:length(obj.pulse_starts)
                sweep(obj.to_samples(obj.pulse_starts(o)) : obj.to_samples(obj.pulse_starts(o)) + obj.to_samples(obj.pulse_lengths(o))) = 1;
            end
        end

        function set(obj, in)
            keyboard()
            start = in(1, :);
            duration = in(2, :);
            duration = repmat(duration, [1, length(start)/length(duration)]);
            for t = 1:length(start)
                obj.pulse_starts = [obj.pulse_starts, start(t)];
                obj.pulse_lengths = [obj.pulse_lengths, max(duration(t), obj.default_trig_length)]; % potentially dangerous, because if trigger is shorter than 5ms it'll fail 
            end
        end

        function flush(obj)
            obj.pulse_starts = [];
            obj.pulse_lengths = [];
        end
    end
end
classdef PulseOutput < handle
    properties
        sample_rate
        pulse_starts
        pulse_lengths
        sweep_length
        pulse_value
    end

    properties (GetAccess = private)
        default_trig_length = 5; % ms
    end

    methods
        function obj = PulseOutput(sample_rate)
            obj.sample_rate = sample_rate;
        end

        function samples = to_samples(obj, ms)
            samples = round(ms * obj.sample_rate / 1000);
        end


        function sweep = generate_sweep(obj)
            sweep = zeros(obj.to_samples(obj.sweep_length), 1);
        end
    end

    methods
        function sweep = add_pulses(obj, sweep)
            if any((obj.pulse_starts + obj.pulse_lengths) > obj.sweep_length)
                error('Trigger longer than sweep length')
            end
            for o = 1:length(obj.pulse_starts)
                sweep(obj.to_samples(obj.pulse_starts(o)) : obj.to_samples(obj.pulse_starts(o)) + obj.to_samples(obj.pulse_lengths(o))) = obj.pulse_value(o);
            end
        end

        function set_trigger(obj, trig_time, trig_duration, pulse_value)
            trig_duration = repmat(trig_duration, [1, length(trig_time)/length(trig_duration)]);
            for t = 1:length(trig_time)
                obj.pulse_starts = [obj.pulse_starts, trig_time(t)];
                obj.pulse_lengths = [obj.pulse_lengths, max(trig_duration(t), obj.default_trig_length)]; % potentially dangerous, because if trigger is shorter than 5ms it'll fail 
                obj.pulse_value = [obj.pulse_value, pulse_value];
            end
        end

        function flush(obj)
            obj.pulse_starts = [];
            obj.pulse_lengths = [];
            obj.pulse_value = [];
        end


    end
end
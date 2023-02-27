classdef PulseOutput < handle
    properties
        sample_rate
        % sweep_length
        % sweep
        % sweep_length_samples
        pulse_starts
        pulse_lengths
        sweep_length
        value
    end

    properties (GetAccess = private)
        default_trig_length = 5; % ms
    end

    methods
        function obj = PulseOutput(sample_rate, val)
            obj.sample_rate = sample_rate;
            obj.value = val;
            % obj.sweep_length = sweep_length;
            % obj.sweep_length_samples = obj.sample_rate*sweep_length;
            % obj.sweep = zeros(1,daq_rate*sweep_length);
        end

        function samples = to_samples(obj, ms)
            samples = ms * obj.sample_rate / 1000;
        end


        function sweep = generate_sweep(obj)
            sweep = zeros(1, obj.to_samples(obj.sweep_length));
        end
        
        % function resetOutput(obj)
        %     obj.sweep = zeros(1,obj.sample_rate*obj.sweep_length);
        % end

        % function show(obj, fig)
        %     if nargin < 2
        %         fig=5;
        %     end
        %     figure(fig)
        %     xs = 1:obj.sweep_length_samples;
        %     xs = xs/obj.sample_rate;
        %     plot(xs, obj.sweep)
        % end

        % function d = double(obj)
        %     d = obj.sweep;
        % end
    end

    methods
        function sweep = add_pulses(obj, sweep)
            if any((obj.pulse_starts + obj.pulse_lengths) > obj.sweep_length)
                error('Trigger longer than sweep length')
            end
            for o = 1:length(obj.pulse_starts)
                sweep(obj.to_samples(obj.pulse_starts(o)) : obj.to_samples(obj.pulse_starts(o)) + obj.to_samples(obj.pulse_lengths(o))) = obj.value;
            end
        end

        function set_trigger(obj, trig_time, trig_duration)
            trig_duration = repmat(trig_duration, [1, length(trig_time)/length(trig_duration)]);
            for t = 1:length(trig_time)
                obj.pulse_starts = [obj.pulse_starts, trig_time(t)];
                obj.pulse_lengths = [obj.pulse_lengths, max(trig_duration(t), obj.default_trig_length)]; % potentially dangerous, because if trigger is shorter than 5ms it'll fail 
            end
            % obj.sweep(trig_start_samples:trig_start_samples+obj.trig_length_samples-1) = 1;
        end

        % function addPulseTrain(obj, trig_times)
        %     for tt=trig_times
        %         obj.addPulse(tt)
        %     end
        % end

        function addStartTrigger(obj)
            % obj.sweep(1:obj.trig_length_samples) = 1;
            obj.pulse_starts = [obj.pulse_starts 1/obj.sample_rate];
        end
    end
end
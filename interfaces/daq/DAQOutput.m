classdef DAQOutput < DAQInterface
    properties
        pulse
    end

    methods
        function obj = DAQOutput(dq, channel)
            obj = obj@DAQInterface(dq, channel);
        end

        function initialize(obj)
            ch = obj.io.addoutput(obj.dev, obj.channel, obj.type);
            if strcmp(obj.type, 'voltage')
                ch.TerminalConfig = 'SingleEnded';
                obj.pulse = SweepGenerator(obj.sample_rate);
            else
                obj.pulse = PulseGenerator(obj.sample_rate);
            end
        end

        function idx = channel_idx(obj)
            names = {obj.io.Channels.ID};
            is_output = cellfun(@(x) strcmp(x, 'OutputOnly'), {obj.io.Channels.MeasurementType});
            % search
            idx = find(cellfun(@(x) strcmp(x, obj.channel), names(is_output)));
        end

        function set(obj, val)
            obj.pulse.set(val)
        end

        function validated = validate(obj, val)
            validated = false;
            if isa(val, 'numeric')% && size(val, 2) == 2
                validated = true;
            end
        end

        function out = get_data(obj)
            out.starts = obj.pulse.pulse_starts;
            out.lengths = obj.pulse.pulse_lengths;
        end

        function set_pulse(obj, start, duration)
            if nargin < 3 || isempty(duration)
                duration = NaN(1, length(start));
            end
            obj.pulse.set(start, duration);
        end

        function sweep = generate_sweep(obj)
            % generate the pulse and get it ready to go
            sweep = obj.pulse.generate();
        end

        function set_trial_length(obj, trial_length)
            obj.pulse.set_trial_length(trial_length);
        end

    end
end
classdef DAQOutput < DAQInterface
    properties
        pulse
    end

    methods
        function obj = DAQOutput(dq, channel)
            obj = obj@DAQInterface(dq, channel);
            obj.pulse = PulseOutput(obj.sample_rate);
        end

        function initialize(obj)
            ch = obj.interface.addoutput(obj.dev, obj.channel, obj.type);
            if strcmp(obj.type, 'voltage')
                ch.TerminalConfig = 'SingleEnded';
            end
        end

        function set(obj, val)
            if obj.validate(val)
                obj.set_pulse(val(:, 1), val(:, 2), val(:, 3));
            else
                fprintf('Improper input, no trigger set\n')
            end
        end

        function validated = validate(obj, val)
            validated = false;
            if isa(val, 'numeric') && size(val, 2) == 3
                validated = true;
            end
        end

        function prepare(obj)
        end

        function set_pulse(obj, start, duration, value)
            if nargin < 3 || isempty(duration)
                duration = NaN(1, length(start));
            end
            obj.pulse.set_pulse(start, duration, value);
        end

        function sweep = generate_sweep(obj)
            % generate the pulse and get it ready to go
            sweep = obj.pulse.generate_sweep();
            sweep = obj.pulse.generate_pulse(sweep);
            obj.pulse.flush();
        end

        function set_trial_length(obj, sweep_length)
            obj.pulse.sweep_length = sweep_length;
        end

    end
end
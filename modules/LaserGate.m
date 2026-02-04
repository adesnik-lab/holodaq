classdef LaserGate < Module
    properties
        gate
    end

    properties (Constant)
        output_value = 3.5; % v, measured for max
    end

    methods
        function obj = LaserGate(gate)
            obj.gate = gate;
        end

        function set(obj, stim, trial_duration)  
            fs = obj.gate.interface.sample_rate;
            sweep = zeros(trial_duration*fs, 1);
            for s = stim
                % loop through the starts and durations and put em in
                n_stims = length(s.pulse_start);
                for i = 1:n_stims
                    sweep(round(s.pulse_start(i)*fs) : round((s.pulse_start(i) + s.pulse_duration(i))*fs)) = obj.output_value;
                end
            end
            obj.gate.set(sweep);
        end
    end
end


classdef LaserSource < Module
    properties
        gate
    end

    properties (Constant)
        output_value = 3.5; % v, measured for max, maybe we should remeasure this sometime?
    end

    methods
        function obj = LaserSource(gate)
            obj.gate = gate;
        end

        function set(obj, stim, trial_duration)
            % check here
            % first, dimensionality
            pulse_starts = cat(1, stim.pulse_start); % if this fails, error out
            pulse_durations = cat(1, stim.pulse_duration);% next, test that they are the same
            if  ~(all(~diff(pulse_durations))) || ~(all(~diff(pulse_starts)))
                error('Values are not equal, can''t do this yet... make the pulse durations and starts equal for red and blue')
            end

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

        % function set_old(obj, stim, trial_duration)  
        %     fs = obj.gate.interface.sample_rate;
        %     sweep = zeros(trial_duration*fs, 1);
        %     for s = stim
        %         % loop through the starts and durations and put em in
        %         n_stims = length(s.pulse_start);
        %         for i = 1:n_stims
        %             sweep(round(s.pulse_start(i)*fs) : round((s.pulse_start(i) + s.pulse_duration(i))*fs)) = obj.output_value;
        %         end
        %     end
        %     obj.gate.set(sweep);
        % end
    end
end


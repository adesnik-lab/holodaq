classdef HolographicPowerControl < Module
    properties (Constant)
        gate_voltage = 3.5; % V, measured for maximum power
    end

    properties
        channels
    end

    methods
        function obj = HolographicPowerControl(channels, source) % source can be the laser gate directly
            obj.channels = channels;
            obj.source = source;
        end

        % function initialize()
        %     % call initialize on each of the sources
        % end

        function prepare()
            for i = 1:length(obj.channels)
                obj.channels(i).prepare()
            end
            obj.source.prepare()
        end


        function set(stim, trial_duration) % can we fudge this and not use trial duration? no.. we need it to generate the appropriate sweep vector
            if length(obj.channels) ~= length(stim)
                error('Number of stim infos must match the number of stim channels');
            end

            for i = 1:length(stim)
                obj.channels(i).set(stim(i), trial_duration); % pass the appropriate stim to the appropriate stimulus, red first, blue second
            end

            obj.source.set(stim, trial_duration);
        end
    end
end
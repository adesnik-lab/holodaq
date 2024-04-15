classdef LaserModulator < Component
    properties
        channel % which driver
    end

    methods

        function obj = LaserModulator(interface, name)
            obj = obj@Component(interface, name);
        end

        function initialize(obj)
            obj.interface.initialize();
        end

        function feed_waveform(obj, input)
            if obj.interface.validate(input)
                obj.interface.set(input);
            else
                fprintf('Invalid input, nothing set \n');
            end
        end
        
        function set(obj, in)
            % turns voltage into something bigger
            % here somehow derive the trial length and get daq sweep length, then take that to create a trace
            % generate the waveform here...
            % ok let's check here...
            if numel(in) == 1
                waveform = obj.generate_waveform(in);
            else
                waveform = in; % then this needs to be a waveform
            end
            obj.feed_waveform(waveform);
        end

        function out = generate_waveform(obj, in)
            sweep = zeros(obj.interface.pulse.sample_rate * obj.interface.pulse.sweep_length/1000, 1);
            sweep(1:end-1) = in;
            out = sweep;
        end

    end
end
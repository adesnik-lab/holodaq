classdef LaserModulator < Component
    properties
        channel % which driver
    end

    methods

        function obj = LaserModulator(interface, channel, name)
            obj = obj@Component(interface, name);
            obj.channel = channel;
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

        function generate_waveform(obj, in)
            keyboard()
        end

    end
end
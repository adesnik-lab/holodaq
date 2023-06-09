classdef Triggerer < Submodule
    properties
        io
        pulse
    end
    
    methods
        function obj = Triggerer(io)
            obj.io = io;
            % switch io.type
            %     case 'voltage'
            %         val = 0.5;
            %     case 'digital'
            %         val = 1;
            % end
            obj.pulse = PulseOutput(io.sample_rate);
        end
        
        function initialize(obj)
            obj.io.add_channel('output');
        end
        
        function start(obj)
        end
        
        function finish(obj)
        end
        
        function set_trial_length(obj, sweep_length)
            obj.pulse.sweep_length = sweep_length;
        end
        
        function feed_sweep(obj, sweep)
            obj.sweep = sweep;
        end

        function set_trigger(obj, trig_time, trig_duration, trig_value)
            if nargin < 3 || isempty(trig_duration)
                trig_duration = NaN(1, length(trig_time));
            end
           
            obj.pulse.set_trigger(trig_time, trig_duration, trig_value);
        end
        
        function sweep = generate_sweep(obj)
                % generate the pulse and get it ready to go
                sweep = obj.pulse.generate_sweep();
                if obj.enabled
                    sweep = obj.pulse.add_pulses(sweep);
                end
                obj.pulse.flush();
        end
        
        function out = get_sweep(obj)
            out = obj.sweep(:);% ensure column
        end
    end
    
end
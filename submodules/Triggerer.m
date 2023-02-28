classdef Triggerer < Submodule
    properties
        io
        pulse
        sweep
    end
    
    methods
        function obj = Triggerer(io)
            obj.io = io;
            switch io.type
                case 'voltage'
                    val = 0.5;
                case 'digital'
                    val = 1;
            end
            obj.pulse = PulseOutput(io.sample_rate, val);
        end
        
        function initialize(obj)
            obj.io.add_channel('output');
        end
        
        function start(obj)
        end
        
        function finish(obj)
        end
        
        function set_pulse_value(obj, value)
            obj.pulse.val = value;
        end
        
        function set_trial_length(obj, sweep_length)
            obj.pulse.sweep_length = sweep_length;
        end
        
        function set_trigger(obj, trig_time, trig_duration)
            if nargin < 3 || isempty(trig_duration)
                trig_duration = NaN(1, length(trig_time));
            end
            
            obj.pulse.set_trigger(trig_time, trig_duration);
        end
        
        function generate_sweep(obj)
            % generate the pulse and get it ready to go
            obj.sweep = obj.pulse.generate_sweep();
            if obj.enabled
                obj.sweep = obj.pulse.add_pulses(obj.sweep);
            end
        end
        
        function out = get_sweep(obj)
            out = obj.sweep;
        end
    end
    
end
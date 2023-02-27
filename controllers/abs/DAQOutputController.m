classdef DAQOutputController < DAQController
    properties
        pulse
    end
    
    methods
        function obj = DAQOutputController(io)
            obj = obj@DAQController(io)
            obj.direction = 'output';
            switch io.type
                case 'voltage'
                    val = 0.5;
                case 'digital'
                    val = 1;
            end
            obj.pulse = PulseOutput(io.dq.Rate, val);
            
        end
        
        function out = prepare(obj)
            out = obj.generate_sweep();
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
        
        function sweep = generate_sweep(obj)
            % generate the pulse and get it ready to go
            sweep = obj.pulse.generate_sweep();
            if obj.enabled
                sweep = obj.pulse.add_pulses(sweep);
            end
        end
        
    end
    
end
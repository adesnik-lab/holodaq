classdef PTBComputer < Module
    properties
        trigger
        stim_onoff
        stim_id
    end
    
    methods
        function obj = PTBComputer(dq, output_channel, onoff_channel, id_channel)
            io = DAQOutput(dq, output_channel);
            obj.trigger = Triggerer(io);
            
            io = DAQInput(dq, onoff_channel);
            obj.stim_onoff = Reader(io);

            io = DAQInput(dq, id_channel);
            obj.stim_id = Reader(io);
        end
        
        function initialize(obj)
            obj.trigger.initialize();
            obj.stim_onoff.initialize();
            obj.stim_id.initialize();
        end
        
        function set_trigger(obj, start, duration, val)
           obj.trigger.io.set_pulse(start, duration, val);
        end
        
        function out = get_sweep(obj);
            out = obj.trigger.sweep;
        end

    end
end
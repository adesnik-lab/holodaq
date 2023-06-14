classdef PTBComputer < Module
    properties
        trigger
        stim_onoff
        stim_id

        saver1
        saver2
        saver3
    end
    
    methods
        function obj = PTBComputer(dq, output_channel, onoff_channel, id_channel)
            io = DAQOutput(dq, output_channel);
            obj.trigger = Triggerer(io);
            
            io = DAQInput(dq, onoff_channel);
            obj.stim_onoff = Reader(io);

            io = DAQInput(dq, id_channel);
            obj.stim_id = Reader(io);

            obj.saver1 = Saver('PTBTrigger');
            obj.saver2 = Saver('stimonoff');
            obj.saver3 = Saver('stimid');
        end
        
        function set_trigger(obj, start, duration, val)
           obj.trigger.io.set_pulse(start, duration, val);
        end
        
        function out = get_sweep(obj);
            out = obj.trigger.sweep;
        end

        function store_trial_data(obj)
            obj.saver1.store(obj.trigger.sweep);
            obj.saver2.store(obj.stim_onoff.data);
            obj.saver3.store(obj.stim_id.data);
        end
    end
end
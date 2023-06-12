classdef PsychToolboxTrigger < Module
    properties
        trigger
        stim_onoff
        stim_id
    end
    
    methods
        function obj = PsychToolboxTrigger(dq, output_channel, onoff_channel, id_channel)
            io = DAQInterface(dq, output_channel);
            obj.trigger = Triggerer(io);
            
            io = DAQInterface(dq, onoff_channel);
            obj.stim_onoff = Reader(io);

            io = DAQInterface(dq, id_channel);
            obj.stim_id = Reader(io);
        end
        
        function initialize(obj)
            obj.trigger.initialize();
            obj.stim_onoff.initialize();
            obj.stim_id.initialize();
        end
        
        function prepare(obj)
           obj.trigger.prepare();
        end
        
        function out = get_sweep(obj);
            out = obj.trigger.sweep;
        end
    end
end
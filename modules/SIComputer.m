classdef SIComputer < Module
    properties
        trigger
        reader
        info

        saver1
        saver2
    end
    
    methods
        function obj = SIComputer(dq, output_channel, input_channel)
            io = DAQOutput(dq, output_channel);
            obj.trigger = Output(io);

            io = DAQInput(dq, input_channel);
            obj.reader = Input(io);
            
            % obj.saver1 = Saver('SITrigger');
            % obj.saver2 = Saver('SIInput');
            % io = MSocketInterface();
            % obj.info = Triggerer(io);
        end
        
        function prepare(obj)
        end
        
        function out = get_sweep(obj)
            out = obj.trigger.sweep;
        end
        
        % function store_trial_data(obj)
        %     obj.saver1.store(obj.trigger.sweep);
        %     obj.saver2.store(obj.reader.data);
        % end
    end
end
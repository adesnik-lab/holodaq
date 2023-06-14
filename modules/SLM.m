classdef SLM < Module
    properties
        trigger
        reader

        saver
    end
    
    methods
        function obj = SLM(dq, output_channel, input_channel)
            io = DAQOutput(dq, output_channel);
            obj.trigger = Triggerer(io);

            io = DAQInput(dq, input_channel);
            obj.reader = Reader(io);

            obj.saver = Saver('slm_flip');
            obj.saver2 = Saver('slm_trigger');
        end

        function prepare(obj)
           obj.trigger.prepare();
        end

        function store_trial_data(obj)
            obj.saver.store(obj.reader.data);
            obj.saver2.store(obj.trigger.sweep);
        end
    end
end
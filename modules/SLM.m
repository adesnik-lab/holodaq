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

            obj.saver = Saver(obj.reader, 'slm');
        end

        function prepare(obj)
           obj.trigger.prepare();
        end

        function save(obj)
            obj.saver.add_data(obj.reader.data);
        end
    end
end
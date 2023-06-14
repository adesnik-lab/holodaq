classdef RunningWheel < Module
    properties
        reader
        saver
    end

    methods
        function obj = RunningWheel(dq, input_channel)
            io = DAQInput(dq, input_channel);
            obj.reader = Reader(io);
            obj.saver = Saver('running_wheel');
        end

        function store_trial_data(obj)
            obj.saver.store(obj.reader.data);
        end
    end
end
classdef ScanImageTrigger < Module
    properties
    end
    
    methods
        function obj = ScanImageTrigger(dq, channel)
            io = DAQInterface(dq, channel);
            controller = DAQOutputController(io);
            obj = obj@Module(controller);
        end
    end
end
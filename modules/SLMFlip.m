classdef SLMFlip < Module
    properties
    end
    
    methods
        function obj = SLMFlip(dq, channel)
            io = DAQInterface(dq, channel);
            controller = DAQInputController(io);
            obj = obj@Module(controller);
        end
    end
end
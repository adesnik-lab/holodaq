classdef SLMFlip < Module
    properties
        reader
    end
    
    methods
        function obj = SLMFlip(dq, channel)
            io = DAQOutput(dq, channel);
            obj.reader = Reader(io);
%             obj.add_submodule(Saver());
        end
        
        function initialize(obj);
            obj.reader.initialize();
        end
    end
end
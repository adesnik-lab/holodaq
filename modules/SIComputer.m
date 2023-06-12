classdef SIComputer < Module
    properties
        trigger
        reader
        info
    end
    
    methods
        function obj = SIComputer(dq, output_channel, input_channel)
            io = DAQOutput(dq, output_channel);
            obj.trigger = Triggerer(io);

            io = DAQInput(dq, input_channel);
            obj.reader = Reader(io);
            
            io = MSocketInterface();
            obj.info = Triggerer(io);
        end
        
        function initialize(obj)
            obj.trigger.initialize();
            obj.reader.initialize();
            %obj.info.initialize();
        end
        
        function prepare(obj)
        end
        
        function out = get_sweep(obj)
            out = obj.trigger.sweep;
        end
    end
end
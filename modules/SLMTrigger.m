classdef SLMTrigger < Module
    properties
        trigger
        reader
    end
    
    methods
        function obj = SLMTrigger(dq, output_channel, input_channel)
            io = DAQOutput(dq, output_channel);
            obj.trigger = Triggerer(io);

            io = DAQInput(dq, input_channel);
            obj.reader = Reader(io);

            % io = MSocketInterface('19...', 2390290);
            
            %obj.holo_computer = MSocketInterface();
        end
        
        function initialize(obj)
            obj.trigger.initialize();
            obj.reader.initialize();
        end
        
        function prepare(obj)
           obj.trigger.prepare();
        end
        
        function out = get_sweep(obj)
            out = obj.trigger.sweep;
        end
    end
end
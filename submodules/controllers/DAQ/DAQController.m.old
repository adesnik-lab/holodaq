classdef DAQController < Controller
    properties
    end
    
    methods
        function obj = DAQController(io)
            obj = obj@Controller(io);
        end
        
        function initialize(obj)
            obj.io.add_channel(obj.direction);
        end
        
    end
end
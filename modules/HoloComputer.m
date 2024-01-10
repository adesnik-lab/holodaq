classdef HoloComputer < Module
    properties
        controller
        
        sequence
    end
    
    methods
        function obj = HoloComputer()
            obj.controller = HolochatInterface('daq');
        end
        
        function set_sequence(obj, sequence)
            obj.sequence = sequence;
        end
        
        function prepare(obj)
            obj.controller.send(obj.sequence, 'holo');
            obj.prepare@Module();
        end
    end
end
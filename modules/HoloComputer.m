classdef HoloComputer < Module
    properties
        sequence
    end

    methods
        function obj = HoloComputer()
            obj.controller = Controller(HolochatInterface('daq'), 'holo');
        end

        function set_sequence(obj, sequence)
            obj.sequence = sequence;
        end

        function prepare(obj)
            obj.controller.send(obj.sequence);
            obj.prepare@Module();
        end

        function holoRequest = transferHR(obj, holoRequest)
            pause(0.5); % or too fast
            if ~isfield(holoRequest, 'roiWeights')
                holoRequest.roiWeights = ones(1,size(holoRequest.targets,1));
            end
            obj.controller.send(holoRequest);
            holoRequest.DE_list = [];
            fprintf('Waiting for DE...')
            while isempty(holoRequest.DE_list)
                holoRequest.DE_list = obj.controller.read();
                % holoRequest.DE_list=msrecv(control,.5);
            end
            fprintf('OK\n')
        end
    end
end
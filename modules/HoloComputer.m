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

        function holoRequest = transferHR(obj, holoRequest)
            pause(0.5); % or too fast
            if ~isfield(holoRequest, 'roiWeights')
                holoRequest.roiWeights = ones(1,size(holoRequest.targets,1));
            end
            obj.controller.send(holoRequest, 'holo');
            % mssend(control, holoRequest);
            holoRequest.DE_list = [];
            fprintf('Waiting for DE...')
            while isempty(holoRequest.DE_list)
                holoRequest.DE_list = obj.controller.read(0.5);
                % holoRequest.DE_list=msrecv(control,.5);
            end
            fprintf('OK\n')
        end
    end
end
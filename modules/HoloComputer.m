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
            % need to turn patterns into struct
            holoRequest.patterns = arrayfun(@struct, holoRequest.patterns);

            obj.controller.send(holoRequest);
            % holoRequest.DE_list = [];
            fprintf('Waiting for Patterns...\n')
            recv = [];
            while isempty(recv)
                recv = obj.controller.read();
            end
            holoRequest.pattern_struct = recv;
            holoRequest.patterns = arrayfun(@Pattern.from_struct, recv);
            fprintf('OK\n')
        end
    end
end
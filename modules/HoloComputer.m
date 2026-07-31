classdef HoloComputer < Module
    properties
        sequence
        % Seconds to wait for the holography computer to return compiled
        % patterns. transferHR used to spin in `while isempty(recv)` forever, so a
        % listener that refused the channel (wrong wavelength set, stopped
        % process) hung the DAQ with no message and no way out but Ctrl-C.
        transfer_timeout = 300
    end

    methods
        function obj = HoloComputer()
            obj.controller = Controller(HolochatInterface('daq'), 'holo');
        end

        function set_sequence(obj, sequence, channel_names)
            %SET_SEQUENCE Firing orders for this trial, one cell per opto channel.
            %   Cell i belongs to opto channel i -- the same order the rig declares
            %   and the order holoRequests were transferred in, which is what the
            %   listener maps to its SLMs. channel_names is optional and used only
            %   to make an arity mismatch legible; the wire form stays a bare cell,
            %   because the listener's serve loop tells a firing order (cell) from
            %   the next holoRequest (struct) by TYPE.
            if nargin >= 3 && ~isempty(channel_names)
                assert(numel(sequence) == numel(channel_names), ...
                    'HoloComputer:sequenceArity', ...
                    ['Got %d firing order(s) for %d opto channel(s) (%s). The ' ...
                     'listener plays cell i\non SLM i, so a short list would leave ' ...
                     'a channel unfed and a long one would\nbe truncated.'], ...
                    numel(sequence), numel(channel_names), ...
                    strjoin(cellstr(channel_names), ', '));
            end
            assert(iscell(sequence), 'HoloComputer:sequenceType', ...
                ['Firing orders must be a CELL array, one entry per channel: the ' ...
                 'listener\ndistinguishes a firing order from a holoRequest by ' ...
                 'type, so sending a struct\nhere would make every trial look like ' ...
                 'a new experiment.']);
            obj.sequence = sequence;
        end

        function prepare(obj)
            obj.controller.send(obj.sequence);
            obj.prepare@Module();
        end

        function holoRequest = transferHR(obj, holoRequest, channel)
            %TRANSFERHR Send a holoRequest for compilation and wait for patterns.
            %   transferHR(hr, channel) additionally TAGS the request with the opto
            %   channel it belongs to, so the listener attributes it by name rather
            %   than by arrival position. Without the tag the listener falls back to
            %   positional order, which is the pre-existing behaviour.
            pause(0.5); % or too fast
            if ~isfield(holoRequest, 'roiWeights')
                holoRequest.roiWeights = ones(1,size(holoRequest.targets,1));
            end

            label = 'holoRequest';
            if nargin >= 3 && ~isempty(channel)
                holoRequest.channel       = char(channel.name);
                holoRequest.wavelength    = double(channel.wavelength);
                holoRequest.channel_index = double(channel.index);
                label = sprintf('%s (%dnm)', channel.name, round(channel.wavelength));
            end

            % need to turn patterns into struct
            holoRequest.patterns = arrayfun(@struct, holoRequest.patterns);

            obj.controller.send(holoRequest);
            % holoRequest.DE_list = [];
            fprintf('Waiting for Patterns [%s]...\n', label)
            recv = [];
            t0 = tic;
            while isempty(recv)
                recv = obj.controller.read();
                if isempty(recv) && toc(t0) > obj.transfer_timeout
                    error('HoloComputer:transferTimeout', ...
                        ['No compiled patterns for %s after %g s.\n' ...
                         'Check the holo computer: the listener refuses a channel ' ...
                         'it has no SLM for,\nand a stopped listener never answers. ' ...
                         'Its console says which.'], ...
                        label, obj.transfer_timeout);
                end
            end
            holoRequest.pattern_struct = recv;
            holoRequest.patterns = arrayfun(@Pattern.from_struct, recv);
            fprintf('OK\n')
        end
    end
end
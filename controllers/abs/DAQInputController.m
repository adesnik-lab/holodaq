classdef DAQInputController < DAQController
    properties
    end

    methods
        function obj = DAQInputController(io)
            obj = obj@DAQController(io);
            obj.direction = 'input';
        end

        function start(obj)
        end

        function finish(obj)
        end
    end

end
classdef Reader < Component
    properties
        io
        data
    end

    methods
        function obj = Reader(io)
            obj.io = io;
        end
        
        function initialize(obj)
            obj.io.initialize();
        end

        function start(obj)
        end

        function finish(obj)
        end
    end

end
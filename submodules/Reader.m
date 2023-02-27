classdef Reader < Submodule
    properties
        io
    end

    methods
        function obj = Reader(io)
            obj.io = io;
        end
        
        function initialize(obj)
            obj.io.add_channel('input');
        end
        
        function start(obj)
        end

        function finish(obj)
        end
    end

end
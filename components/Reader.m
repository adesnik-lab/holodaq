classdef Reader < matlab.mixin.Heterogeneous & handle
    properties
        data
        io
    end
    methods
        function obj = Reader(io)
            obj.io = io;
        end
        
        function read(obj)
            obj.data = obj.io.get_data();
        end

        function start(obj)
        end

        function finish(obj)
        end
    end

end
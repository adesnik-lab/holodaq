classdef Reader < matlab.mixin.Heterogeneous & handle
    properties
        data
        io
        enabled = false;
    end
    methods
        function obj = Reader(io)
            obj.io = io;
        end
        
        function read(obj)
            if obj.enabled
            obj.data = obj.io.get_data();
            end
        end

        function start(obj)
        end

        function finish(obj)
        end
    end

end
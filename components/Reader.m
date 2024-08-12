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
        
        function read(obj, data)
            if obj.enabled
                obj.data = obj.io.get_data(data);
            end
        end

        function start(obj)
        end

        function finish(obj)
        end
    end

end
classdef Reader < Submodule
    properties
        io
        data
    end

    methods
        function obj = Reader(io)
            obj.io = io;
        end
        
        function initialize(obj)
            obj.io.add_channel('input');
        end
        
        function get_data(obj)
            % Data is automatically read, we jsut need to appropriately
            % extract it
        end

        function start(obj)
        end

        function finish(obj)
        end
    end

end
classdef Input < Component
    properties
        data
    end
    methods
        function obj = Input(io, name)
            obj = obj@Component(io, name);
        end
        
        function initialize(obj)
            obj.io.initialize();
        end

        function read(obj)
            tic
            obj.data = obj.io.get_data();
            tco
        end

        function start(obj)
        end

        function finish(obj)
        end
    end

end
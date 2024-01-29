classdef Input < Component
    properties
        data
    end
    methods
        function obj = Input(interface, name)
            obj = obj@Component(interface, name);
        end
        
        function initialize(obj)
            obj.interface.initialize();
        end

        function read(obj)
            tic
            obj.data = obj.interface.get_data();
            tco
        end

        function start(obj)
        end

        function finish(obj)
        end
    end

end
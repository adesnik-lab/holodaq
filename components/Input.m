classdef Input < Component
    properties
        % data
        reader
    end
    methods
        function obj = Input(interface, name)
            obj = obj@Component(interface, name);
            obj.reader = Reader(interface);
        end
        
        function initialize(obj)
            obj.interface.initialize();
        end

        % function read(obj)
        %     obj.data = obj.interface.get_data();
        % end

        function start(obj)
        end

        function finish(obj)
        end
    end

end
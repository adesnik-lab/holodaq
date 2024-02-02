classdef Controller < Component
    properties
    end

    methods
        function obj = Controller(interface, name)
            obj = obj@Component(interface, name);
        end
        
        function send(obj, data)
            obj.interface.send(data, obj.name);
        end

        function read(obj)

        end

        function config(obj, data)
            obj.interface.config(data, obj.name);
        end
    end
end
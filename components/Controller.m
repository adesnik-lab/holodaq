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

        function out = read(obj)
            out = obj.interface.read();
        end

        function set_config(obj, data)
            obj.interface.set_config(data, obj.name);
        end

        function get_config(obj)
        end
    end
end
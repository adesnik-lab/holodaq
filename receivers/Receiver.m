classdef Receiver < handle
    properties
        interface
        config
    end

    methods
        function obj = Receiver(name)
            obj.interface = HolochatInterface(name);
            obj.config = obj.interface.get_config(name);
            obj.run();
        end

        function run(obj)
        end
    end
end
classdef Component < matlab.mixin.Heterogeneous & handle
    properties
        interface
        name
    end
    
    methods
        function obj = Component(interface, name)
            obj.interface = interface;
            obj.name = name;
        end

        function initialize(obj)
        end

        function prepare(obj)
        end
    end
end


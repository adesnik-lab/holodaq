classdef Component < matlab.mixin.Heterogeneous & handle
    properties
        reader
        interface
        name
    end
    
    methods
        function obj = Component(interface, name)
            obj.interface = interface;
            obj.reader = Reader(interface);
            obj.name = name;
        end

        function initialize(obj)
        end

        function prepare(obj)
        end
    end
end


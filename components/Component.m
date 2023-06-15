classdef Component < matlab.mixin.Heterogeneous & handle
    properties
        reader
        io
        name
    end
    
    methods
        function obj = Component(io, name)
            obj.io = io;
            obj.reader = Reader(io);
            obj.name = name;
        end

        function initialize(obj)
        end
    end
end


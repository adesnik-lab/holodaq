classdef Triggerer < Submodule
    properties
        io
    end
    
    methods
        function obj = Triggerer(io)
            obj.io = io;
        end
        
        function initialize(obj)
            obj.io.initialize();
        end
    
        function set(obj, input)
            obj.io.set(input);
        end

        function prepare(obj)
            obj.io.prepare();
        end
        
        function start(obj)
            obj.io.start();
        end
        
        function finish(obj)
            obj.io.finish();
        end
    end
    
end
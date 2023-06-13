classdef Triggerer < Component
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
            if obj.io.validate(input)
                obj.io.set(input);
            else
                fprintf('Invalid input, nothing set \n');
            end
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
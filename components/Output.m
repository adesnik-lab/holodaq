classdef Output < Component
    properties
    end
    
    methods
        function obj = Output(interface, name)
            obj = obj@Component(interface, name);
        end
        
        function initialize(obj)
            obj.interface.initialize();
        end
    
        function set(obj, input)
            if obj.interface.validate(input)
                obj.interface.set(input);
            else
                keyboard();
                fprintf('Invalid input, nothing set \n');
            end
        end

        function prepare(obj)
            obj.interface.prepare();
        end
        
        function start(obj)
            obj.interface.start();
        end
        
        function finish(obj)
            obj.interface.finish();
        end
    end
    
end
classdef Reader < Component
    properties
        data
    end

    % give each reader its own "read" method which propertly interfaces with its interface?
    % if you read the data ance in the DAQ, does it go away? can you read it in multiple times?
    methods
        function obj = Reader(io)
            obj.io = io;
        end
        
        function initialize(obj)
            obj.io.initialize();
        end

        function read(obj)
            disp('work here')
            % obj.data = obj.io.get_data();
        end
        function start(obj)
        end

        function finish(obj)
        end
    end

end
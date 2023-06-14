classdef Reader < Component
    properties
        io
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
            obj.data = obj.io.get_data();
            % somethnig goes here that properly interfaces with each interface to read the appropriate data form?
            %this means that the read function actually nedes to be in the interface, some kind of "get_data" kinda thing... ok.
            %DAQ -> some kind of input parsing, or for outputs feed the trigger, year
            % MSocket -> just reads in the thing? idk
            % ModuleIO -> 
        end
        function start(obj)
        end

        function finish(obj)
        end
    end

end
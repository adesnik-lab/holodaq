classdef Controller < Component
    properties
        controllee

        mouse % these are default things that we need for the experiment
        epoch

        data

        is_enabled
    end

    methods
        function obj = Controller(io, name)
            obj = obj@Component(io, name);
        end

        function initialize(obj)
            fprintf('Initiliazing %s...', obj.name)
            obj.io.connect();
            obj.io.send(obj.name);
            obj.controllee = obj.io.read();
            fprintf('OK.\n');
        end

        function set(obj, data)
            obj.data = data;
        end

        function enable(obj)
            obj.is_enabled = true;
        end

        function disable(obj)
            obj.is_enabled = false;
        end
    end
end
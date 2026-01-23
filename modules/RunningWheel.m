
classdef RunningWheel < Module
    properties
        wheel
    end

    methods
        function obj = RunningWheel(wheel)
            obj.wheel = wheel;
        end

        function out = get_data(obj)
            % read everything from the thing...
            data = textscan(obj.wheel.io.read(obj.wheel.io.NumBytesAvailable, 'char'), '%f', 'Delimiter', 'CR/LF');
            out.('RunningWheel') = data{1};
        end
        function initialize(obj)
            initialize@Module(obj);
        end

        function prepare(obj)
            prepare@Module(obj); 
            obj.wheel.flush();
        end
    end
end
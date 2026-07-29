classdef fakedaq < handle
    properties
        Rate
        dev = 'Dev1'
    end
    
    methods
        function obj = fakedaq()
            dev = rig_get('daq.device', '');
            if ~isempty(dev)
                obj.dev = dev;   % 'Dev1' property default when no rig is loaded
            end
        end
        function ch = addinput(obj, varargin)
            disp('Added input')
            ch = [];
        end
        
        function ch = addoutput(obj, varargin)
            disp('Added output')
            ch = [];
        end
        
        function out = readwrite(obj, varargin)
            disp('readwrite')
            out = [];
        end

        function write(obj, data)
            disp('wrote')
        end
    end
end
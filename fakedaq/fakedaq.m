classdef fakedaq < handle
    properties
        Rate
        dev = 'Dev1'
    end
    
    methods
        function obj = daq()
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
    end
end
classdef SessionManager < handle
    %SESSIONMANAGER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        tm % trial manager
        saver

        mouse
        epoch
        experiment
    end
    
    methods
        function obj = SessionManager(tm, mouse, epoch, experiment)
            obj.mouse = mouse;
            obj.epoch = epoch;
            obj.experiment = experiment;
            obj.tm = tm;
            obj.saver = Saver(mouse, epoch, experiment);
        end

        function start_session(obj)
            fprintf('Starting session...\n')
            obj.tm.initialize();
        end
        
        function end_session(obj)
            fprintf('Ending session.\n')
            obj.saver.save('all');
        end
    end
end


classdef SessionManager < handle
    %SESSIONMANAGER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        tm % trial manager
        saver

        mouse
        epoch
        experiment
        vis_stim
        controller
    end
    
    methods
        function obj = SessionManager(tm, experiment, save_flag, vis_stim)
            if nargin < 4
                vis_stim = [];
            end
            if nargin < 3 || isempty(save_flag)
                save_flag = true;
            end
            if save_flag
                [mouse, epoch] = obj.query();
                obj.mouse = mouse;
                obj.epoch = epoch;
                obj.experiment = experiment;
                obj.vis_stim = vis_stim;
                obj.saver = Saver(mouse, epoch, experiment);
            end
                        obj.tm = tm;

            obj.controller = HolochatInterface('daq');
        end

        function start_session(obj)
            fprintf('Starting session...\n')
            session_info.mouse = obj.mouse;
            session_info.epoch = obj.epoch;
            session_info.experiment = obj.experiment;
            session_info.vis_stim = obj.vis_stim;

            % initialize the trial manager and daq
            obj.tm.initialize();

            for c = obj.tm.modules.extract('Controller')
                c.set_config(session_info);
                % c.send('go');
            end
        end

        function [mouse, epoch] = query(obj)
            answer = inputdlg({'Mouse', 'Epoch #'}, 'Session information');
            mouse = answer{1};
            epoch = str2num(answer{2});
        end
        

        function end_session(obj)
            fprintf('Ending session.\n')
            if ~isempty(obj.saver)
            obj.saver.save('all');
            end
        end
    end
end


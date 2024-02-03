classdef SIReceiver < Receiver
    properties
        hSI
        hSICtl
    end

    methods
        function obj = SIReceiver()
            obj = obj@Receiver('si');
        end

        function run(obj)
            % get info from config
            mouse = obj.config.mouse;
            epoch = obj.config.epoch;
            expt = obj.config.experiment;

            obj.hSI = evalin('base', 'hSI');
            obj.hSICtl = evalin('base', 'hSICtl');
            obj.hSI.extTrigEnable = 1;
            obj.hSI.hChannels.loggingEnable = 1;
            obj.hSI.hScan2D.logFilePath = sprintf('D:/%s/%s/%d%s', datetime('now', 'format', 'yyMMdd'), mouse, epoch, expt);
            obj.hSI.hScan2D.logFileStem = sprintf('%s_%s_%d%s', datetime('now', 'format', 'yyMMdd'), mouse, epoch, expt);
            obj.hSI.hScan2D.logFileCounter = 1;
            obj.hSICtl.updateView();

            obj.callback(expt);

            obj.hSI.startLoop();      
            disp('Started!')
        end

        function callback(obj, expt)
            obj.disable_all_user_functions();
            switch expt
                case 'oricon'
                    % set the oricon callback
                    obj.enable_user_function('ori_contrast_callback');
            end
        end

        function disable_all_user_functions(obj)
            for ii = 1:numel(obj.hSI.hUserFunctions.userFunctionsCfg)
                obj.hSI.hUserFunctions.userFunctionsCfg(ii).Enable = 0;
            end
        end

        function enable_user_function(obj, user_function)
            idx = cellfun(@(x) strcmp(x, user_function), {obj.hSI.hUserFunctions.userFunctionsCfg.UserFcnName});
            obj.hSI.hUserFunctions.userFunctionsCfg(idx).Enable = 1;
        end
    end
end
classdef SIReceiver < Receiver
    properties
        hSI
        hSICtl
    end

    methods
        function obj = SIReceiver(hSI, hSICtl)
            obj = obj@Receiver('si');
            obj.hSI = hSI;
            obj.hSICtl = hSICtl;
        end

        function run(obj)
            % get info from config
            mouse = obj.config.mouse;
            epoch = obj.config.epoch;
            expt = obj.config.experiment;

               
            obj.hSI.extTrigEnable = 1;
            obj.hSI.hChannels.loggingEnable = 1;
            obj.hSI.hScan2D.logFilePath = sprintf('D:/%s/%s/%d%s', datetime('now', 'format', 'yyMMdd'), mouse, epoch, expt);
            obj.hSI.hScan2D.logFileStem = sprintf('%s_%s_%d%s', datetime('now', 'format', 'yyMMdd'), mouse, epoch, expt);
            obj.hSI.hScan2D.logFileCounter = 1;
            obj.hSICtl.updateView();

            obj.hSI.startGrab();
            % set trigger
            % set filename
            % start loop
            % enable callbacks?
            
        end

        function callback(obj, expt)
            switch expt
                case 'oricon'
                    % set the oricon callback
                otherwise
                    % turn off callbacks
            end
        end
    end
end
classdef SIReceiver < Receiver
    %SIRECEIVER Persistent ScanImage primer. Run once on the SI computer via
    %   start_si_listener. On each new experiment prime it sets the save
    %   filename to match the DAQ's Saver stem, enables logging + external
    %   trigger, enables the experiment's user function, and arms acquisition
    %   (startLoop) so ScanImage waits for the DAQ trigger. Requires hSI/hSICtl
    %   in the base workspace.

    properties
        hSI
        hSICtl
    end

    methods
        function obj = SIReceiver()
            obj = obj@Receiver('si');
        end

        function run(obj)
            mouse = obj.config.mouse;
            epoch = obj.config.epoch;
            expt  = obj.config.experiment;
            stamp = obj.date_stamp();

            obj.hSI    = evalin('base', 'hSI');
            obj.hSICtl = evalin('base', 'hSICtl');

            % Stop any prior looped acquisition before re-arming for a new expt.
            try, obj.hSI.abort(); catch, end

            obj.hSI.extTrigEnable            = 1;
            obj.hSI.hChannels.loggingEnable  = 1;
            % logFileStem MUST match the DAQ Saver stem <date>_<mouse>_<epoch><expt>
            % so OnlineSession can pair the tiffs with the K: stim-data file.
            obj.hSI.hScan2D.logFilePath    = sprintf('D:/%s/%s/%d%s', stamp, mouse, epoch, expt);
            obj.hSI.hScan2D.logFileStem    = sprintf('%s_%s_%d%s', stamp, mouse, epoch, expt);
            obj.hSI.hScan2D.logFileCounter = 1;
            obj.hSICtl.updateView();

            obj.set_user_function();

            obj.hSI.startLoop();      % arm: wait for the DAQ external trigger
            disp('ScanImage armed.')
        end

        function stamp = date_stamp(obj)
            % Prefer the prime's date so tiffs line up with the DAQ save file.
            if isstruct(obj.config) && isfield(obj.config, 'date') && ~isempty(obj.config.date)
                stamp = char(obj.config.date);
            else
                stamp = char(datetime('now', 'Format', 'yyMMdd'));
            end
        end

        function set_user_function(obj)
            % Enable the experiment's ScanImage user function (from the prime's
            % si_callback), disabling all others. No-op when si_callback is ''.
            obj.disable_all_user_functions();
            cb = '';
            if isstruct(obj.config) && isfield(obj.config, 'si_callback')
                cb = char(obj.config.si_callback);
            end
            if ~isempty(cb)
                obj.enable_user_function(cb);
            end
        end

        function disable_all_user_functions(obj)
            for ii = 1:numel(obj.hSI.hUserFunctions.userFunctionsCfg)
                obj.hSI.hUserFunctions.userFunctionsCfg(ii).Enable = 0;
            end
        end

        function enable_user_function(obj, user_function)
            idx = cellfun(@(x) strcmp(x, user_function), ...
                {obj.hSI.hUserFunctions.userFunctionsCfg.UserFcnName});
            if any(idx)
                obj.hSI.hUserFunctions.userFunctionsCfg(idx).Enable = 1;
            else
                warning('SIReceiver: user function "%s" not found in ScanImage.', user_function);
            end
        end
    end
end

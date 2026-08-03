classdef PowerControllerCalibrated < matlab.apps.AppBase
    % PowerControllerCalibrated
    %   Like PowerControllerSimple (900 + 1100 channels), but:
    %     (1) reads a power->HWP-angle calibration LUT per channel so you request
    %         power in mW with a SLIDER whose track shows the min..max of the
    %         calibrated range. mW is converted to HWP degrees via interp1, the same
    %         way PowerChannel/FiberPowerControl do it.
    %     (2) drives the laser gate analog output directly: a LASER toggle sets the
    %         output voltage to MAX_LASER_VOLTAGE (on) or 0 (off). Max voltage is the
    %         gate_voltage=3.5 V from holodaq/modules/HolographicPowerControl.m.
    %     (3) adds a momentary PULSE button per channel that opens the shutter for
    %         PULSE_DURATION seconds then closes it, on top of the normal open/close
    %         toggle.

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure            matlab.ui.Figure
        GridLayout          matlab.ui.container.GridLayout

        % --- laser gate ---
        LASERButton         matlab.ui.control.StateButton   % on/off -> voltage max/0
        VoltageLabel        matlab.ui.control.Label         % readout

        % --- per channel: 900 / 1100 ---
        Label900            matlab.ui.control.Label
        Label1100           matlab.ui.control.Label

        Power900            matlab.ui.control.Slider   % mW request (track shows range)
        Power1100           matlab.ui.control.Slider

        PowerReadout900     matlab.ui.control.Label    % live "xx.x mW"
        PowerReadout1100    matlab.ui.control.Label

        SHUTTER900Button    matlab.ui.control.StateButton
        SHUTTER1100Button   matlab.ui.control.StateButton

        PULSE900Button      matlab.ui.control.Button   % momentary open->wait->close
        PULSE1100Button     matlab.ui.control.Button
    end

    properties (Constant)
        PULSE_DURATION    = 0.5;   % s, momentary open time for the PULSE buttons
        % Status colours: green = safe (shutter closed / laser off), red = live
        % (shutter open / laser on), so state is obvious at a glance.
        COLOR_IDLE   = [0.30 0.65 0.40];   % green
        COLOR_ACTIVE = [0.85 0.16 0.16];   % red
        % LUT paths come from the rig file (rig.modules.fpc_*.calibration);
        % see startupFcn.
    end

    properties (Access = private)
        hwp900
        hwp1100

        shutter900
        shutter1100

        laser_voltage        % current commanded gate voltage (V)

        % power(mW)->deg interpolants + limits per channel ([] if no LUT)
        pwr_fun900;  min_pwr900;  max_pwr900
        pwr_fun1100; min_pwr1100; max_pwr1100

        dq

        % V, gate "on" voltage; default from HolographicPowerControl.gate_voltage,
        % overridden by rig.modules.laser_gate.max_voltage (see startupFcn)
        MAX_LASER_VOLTAGE double = 3.5

        % Position of [shutter900, shutter1100, laser] in the DAQ output vector;
        % 0 = channel absent on this rig (not in the rig file). See build_output.
        out_idx = [0 0 0]

        Simulate    logical = false   % off-rig: skip all hardware I/O
        WantVisible logical = true    % show the uifigure (false = headless)
    end

    methods (Access = private)

        % ---- DAQ helpers ----------------------------------------------------
        % Output vector order matches the order outputs are added in startupFcn:
        %   [shutter900, shutter1100, laser_voltage], minus any channel the rig
        % file omits. out_idx maps each logical channel to its vector position.
        function data = build_output(app)
            vals = cat(2, app.shutter900, app.shutter1100, app.laser_voltage);
            data = vals(app.out_idx > 0);   % startupFcn adds outputs in vals order
        end

        function open(app, shutter_id)
            if app.Simulate, return; end   % caller still latches the shadow state
            idx = app.out_idx(shutter_id);
            if idx == 0, return; end       % channel not on this rig
            data = app.build_output();
            data(idx) = 1;
            app.dq.write(data);
        end

        function close(app, shutter_id)
            if app.Simulate, return; end
            idx = app.out_idx(shutter_id);
            if idx == 0, return; end       % channel not on this rig
            data = app.build_output();
            data(idx) = 0;
            app.dq.write(data);
        end

        function write_voltage(app)
            if ~app.Simulate
                data = app.build_output();
                if ~isempty(data)
                    app.dq.write(data);
                end
            end
            app.VoltageLabel.Text = sprintf('%.2f V', app.laser_voltage);
        end

        function rotate(app, hwp, deg)
            if app.Simulate, return; end
            hwp.set(deg);
        end

        % ---- calibration ----------------------------------------------------
        % Same LUT as FiberPowerControl (power in WATTS -> HWP degrees), minus the
        % kHz scaling (no longer used). We expose a mW-based interpolant (the slider
        % is in mW) -> HWP degrees, plus the range in mW for the slider limits.
        function [fun, min_mW, max_mW] = load_lut(~, path_to_lut)
            fun = []; min_mW = []; max_mW = [];
            if isempty(path_to_lut)
                return
            end
            calib  = importdata(path_to_lut);
            [~, u] = unique(calib.powers);
            watts  = calib.powers(u);                             % LUT power axis (W)
            fun    = @(mW) interp1(watts, calib.degrees(u), mW/1000);
            min_mW = calib.min_power * 1000;                      % W -> mW for the slider
            max_mW = calib.max_power * 1000;
        end

        % Point a slider at a channel's calibrated range, or disable it if no LUT.
        function init_slider(~, slider, readout, minp, maxp)
            if isempty(minp)
                slider.Enable = 'off';
                readout.Text  = 'n/a';
                return
            end
            % Order matters: the current Value must stay inside Limits at every step.
            % The placeholder Limits set in createComponents are wide, so minp is valid.
            slider.Value      = minp;                       % move inside the target band first
            slider.Limits     = [minp maxp];
            slider.MajorTicks = linspace(minp, maxp, 5);
            readout.Text      = sprintf('%.1f mW', minp);
        end

        % Slider moved: clamp, convert mW->deg, rotate the HWP, update readout.
        function set_power(app, fun, minp, maxp, hwp, slider, readout)
            if isempty(fun)
                return
            end
            req_mW = min(max(slider.Value, minp), maxp);
            slider.Value = req_mW;
            readout.Text = sprintf('%.1f mW', req_mW);
            deg = fun(req_mW);
            if isnan(deg)
                disp('Power out of range');
                return
            end
            app.rotate(hwp, deg);
        end

        % Momentary open -> wait -> restore for the PULSE buttons. Non-blocking: a
        % one-shot timer restores the latched shutter state after PULSE_DURATION, so
        % the UI stays responsive during the pulse.
        function pulse(app, shutter_id)
            app.open(shutter_id);
            t = timer('ExecutionMode', 'singleShot', 'StartDelay', app.PULSE_DURATION);
            t.TimerFcn = @(src, ~) app.finish_pulse(src);
            start(t);
        end

        function finish_pulse(app, t)
            if isvalid(app) && ~app.Simulate     % app may have closed during the pulse
                app.dq.write(app.build_output());  % restore latched shutter states
            end
            delete(t);
        end
    end

    % Callbacks that handle component events
    methods (Access = private)

        function startupFcn(app)
            if app.Simulate
                % Off-rig: no DAQ / serial. Fake calibrated ranges so the
                % sliders + status view behave like the real thing.
                app.shutter900 = 0; app.shutter1100 = 0; app.laser_voltage = 0;
                [app.pwr_fun900,  app.min_pwr900,  app.max_pwr900]  = deal(@(mW) 0, 5, 120);
                [app.pwr_fun1100, app.min_pwr1100, app.max_pwr1100] = deal(@(mW) 0, 5, 150);
                app.init_slider(app.Power900,  app.PowerReadout900,  app.min_pwr900,  app.max_pwr900);
                app.init_slider(app.Power1100, app.PowerReadout1100, app.min_pwr1100, app.max_pwr1100);
                app.write_voltage();
                disp('PowerControllerCalibrated: SIMULATE mode (no hardware).')
                return
            end

            % Everything rig-specific (DAQ device, channels, serial port, LUT
            % paths) comes from the rig file (rigs/<Name>Rig.m); a channel the
            % rig file omits is skipped and its controls are disabled.
            addpath(fullfile(fileparts(mfilename('fullpath')), 'rigs'));
            rig = load_rig();

            % FAIL CLOSED on a rig this GUI cannot represent. Every control here
            % is hardcoded to exactly two channels -- the sliders, channelState's
            % s.ch900/s.ch1100, idForChannel's 1=900/2=1100, and critically
            % allSafe, which closes exactly two shutters. On a rig with one
            % channel the extra controls would command nothing; on a rig with
            % three, E-STOP would leave the third shutter OPEN while reporting
            % everything safe. Refusing to open is the safe response, and it says
            % what to do about it. Experiments themselves are N-channel via
            % rig.opto (see opto_channels); only this GUI is not yet.
            n_opto = numel(opto_channels(rig));
            assert(n_opto == 0 || n_opto == 2, 'PowerControllerCalibrated:channelCount', ...
                ['This GUI supports exactly two opto channels, but rig ''%s'' ' ...
                 'declares %d.\nIts E-STOP closes two shutters by name, so on ' ...
                 'your rig it could report\n"all safe" with a shutter still open. ' ...
                 'Use ScopeController''s other controls, or\ngeneralize this GUI ' ...
                 'to loop rig.opto before running it here.'], rig.name, n_opto);

            has900  = rig_has(rig, 'fpc_900');
            has1100 = rig_has(rig, 'fpc_1100');
            hasgate = rig_has(rig, 'laser_gate');

            app.dq = daq(rig.daq.vendor);
            dev = rig.daq.device;
            if isempty(dev)
                dl = daqlist();
                dev = dl.DeviceID(1);   % auto-detect, same as DAQInterface
            end

            % The HWPs (ELL14) share one serial bus; open it once if either
            % power channel exists.
            if has900 || has1100
                if has900, sname = rig.modules.fpc_900.serial; else, sname = rig.modules.fpc_1100.serial; end
                s = open_serial(rig.serial.(sname));
            end

            % Shutters (digital) + HWPs (ELL14 on serial), then the laser gate
            % (analog out) LAST — build_output relies on this order; out_idx
            % records each channel's position in the output vector.
            n_out = 0;
            cal900 = ''; cal1100 = '';
            if has900
                app.dq.addoutput(dev, rig.modules.fpc_900.shutter, 'Digital');
                n_out = n_out + 1; app.out_idx(1) = n_out;
                app.hwp900 = ELL14(SerialInterface(s), rig.modules.fpc_900.ell14_channel, 'hwp');
                cal900 = rig.modules.fpc_900.calibration;
            else
                app.SHUTTER900Button.Enable = 'off';
                app.PULSE900Button.Enable   = 'off';
            end
            app.shutter900 = 0;

            if has1100
                app.dq.addoutput(dev, rig.modules.fpc_1100.shutter, 'Digital');
                n_out = n_out + 1; app.out_idx(2) = n_out;
                app.hwp1100 = ELL14(SerialInterface(s), rig.modules.fpc_1100.ell14_channel, 'hwp');
                cal1100 = rig.modules.fpc_1100.calibration;
            else
                app.SHUTTER1100Button.Enable = 'off';
                app.PULSE1100Button.Enable   = 'off';
            end
            app.shutter1100 = 0;

            if hasgate
                app.dq.addoutput(dev, rig.modules.laser_gate.output, 'Voltage');
                n_out = n_out + 1; app.out_idx(3) = n_out;
                if isfield(rig.modules.laser_gate, 'max_voltage')
                    app.MAX_LASER_VOLTAGE = rig.modules.laser_gate.max_voltage;
                end
            else
                app.LASERButton.Enable = 'off';
            end
            app.laser_voltage = 0;

            % Load calibrations (mW -> HWP degrees) and point each slider at its
            % range; an empty LUT path leaves that slider disabled.
            [app.pwr_fun900,  app.min_pwr900,  app.max_pwr900]  = app.load_lut(cal900);
            [app.pwr_fun1100, app.min_pwr1100, app.max_pwr1100] = app.load_lut(cal1100);
            app.init_slider(app.Power900,  app.PowerReadout900,  app.min_pwr900,  app.max_pwr900);
            app.init_slider(app.Power1100, app.PowerReadout1100, app.min_pwr1100, app.max_pwr1100);

            app.write_voltage();   % push initial 0 V + closed shutters
            disp('Devices connected.')
        end

        % ---- laser gate ----
        function LASERButtonValueChanged(app, event)
            if app.LASERButton.Value
                app.laser_voltage = app.MAX_LASER_VOLTAGE;
                app.LASERButton.Text = 'LASER ON';
                app.LASERButton.BackgroundColor = app.COLOR_ACTIVE;   % red
            else
                app.laser_voltage = 0;
                app.LASERButton.Text = 'LASER OFF';
                app.LASERButton.BackgroundColor = app.COLOR_IDLE;     % green
            end
            app.write_voltage();
        end

        % ---- power (mW) sliders ----
        function Power900ValueChanged(app, event)
            app.set_power(app.pwr_fun900, app.min_pwr900, app.max_pwr900, ...
                app.hwp900, app.Power900, app.PowerReadout900);
        end
        function Power1100ValueChanged(app, event)
            app.set_power(app.pwr_fun1100, app.min_pwr1100, app.max_pwr1100, ...
                app.hwp1100, app.Power1100, app.PowerReadout1100);
        end

        % ---- shutter toggles ----
        function SHUTTER900ButtonValueChanged(app, event)
            if app.SHUTTER900Button.Value
                app.open(1); app.shutter900 = 1;
                app.SHUTTER900Button.Text = 'OPEN';
                app.SHUTTER900Button.BackgroundColor = app.COLOR_ACTIVE;   % red
                app.Label900.BackgroundColor = app.COLOR_ACTIVE;
            else
                app.close(1); app.shutter900 = 0;
                app.SHUTTER900Button.Text = 'CLOSED';
                app.SHUTTER900Button.BackgroundColor = app.COLOR_IDLE;     % green
                app.Label900.BackgroundColor = 'none';
            end
        end
        function SHUTTER1100ButtonValueChanged(app, event)
            if app.SHUTTER1100Button.Value
                app.open(2); app.shutter1100 = 1;
                app.SHUTTER1100Button.Text = 'OPEN';
                app.SHUTTER1100Button.BackgroundColor = app.COLOR_ACTIVE;  % red
                app.Label1100.BackgroundColor = app.COLOR_ACTIVE;
            else
                app.close(2); app.shutter1100 = 0;
                app.SHUTTER1100Button.Text = 'CLOSED';
                app.SHUTTER1100Button.BackgroundColor = app.COLOR_IDLE;    % green
                app.Label1100.BackgroundColor = 'none';
            end
        end

        % ---- momentary pulse buttons (0.5 s) ----
        function PULSE900ButtonPushed(app, event),  app.pulse(1); end
        function PULSE1100ButtonPushed(app, event), app.pulse(2); end

        % ---- window close: delete the app so hardware is released ----
        function UIFigureCloseRequest(app, ~)
            delete(app)
        end
    end

    % Programmatic control surface -------------------------------------------
    % So a remote bridge (or a script) can drive the exact same logic as the
    % on-screen buttons: each method sets the relevant component value and then
    % invokes the existing callback, keeping ONE implementation of every action.
    methods (Access = public)

        function laser(app, on)
            app.LASERButton.Value = logical(on);
            app.LASERButtonValueChanged();
        end

        function shutter(app, channel, open)
            if channel == 900
                app.SHUTTER900Button.Value = logical(open);
                app.SHUTTER900ButtonValueChanged();
            else
                app.SHUTTER1100Button.Value = logical(open);
                app.SHUTTER1100ButtonValueChanged();
            end
        end

        function firePulse(app, channel)
            app.pulse(app.idForChannel(channel));   % private pulse(): 1=900, 2=1100
        end

        function setPowerMW(app, channel, mW)
            if channel == 900, sl = app.Power900; else, sl = app.Power1100; end
            if strcmp(sl.Enable, 'off'), return; end   % channel has no calibration
            sl.Value = mW;                             % set_power clamps to range
            if channel == 900
                app.Power900ValueChanged();
            else
                app.Power1100ValueChanged();
            end
        end

        function allSafe(app)
            % Laser off + both shutters closed (reuses the toggle logic).
            app.laser(false);
            app.shutter(900, false);
            app.shutter(1100, false);
        end

        function s = state(app)
            % Snapshot of commanded state for the remote status board.
            s = struct();
            s.laser_on      = logical(app.LASERButton.Value);
            s.laser_voltage = app.laser_voltage;
            s.ch900  = app.channelState(app.Power900,  app.pwr_fun900,  app.min_pwr900,  app.max_pwr900,  app.shutter900);
            s.ch1100 = app.channelState(app.Power1100, app.pwr_fun1100, app.min_pwr1100, app.max_pwr1100, app.shutter1100);
        end

        function releaseHardware(app)
            % Give up the DAQ + serial so an Experiment can claim them. Safe to
            % call repeatedly; a no-op in simulate mode.
            if app.Simulate, return; end
            try, app.allSafe(); catch, end
            try
                if ~isempty(app.dq) && isvalid(app.dq), stop(app.dq); end
            catch
            end
            app.dq     = [];
            app.hwp900 = [];   % clearing the ELL14s closes the shared COM4 port
            app.hwp1100 = [];
        end
    end

    methods (Access = private)
        function id = idForChannel(~, channel)
            if channel == 900, id = 1; else, id = 2; end
        end

        function c = channelState(~, slider, fun, minp, maxp, shutter_state)
            c = struct();
            c.shutter_open = logical(shutter_state);
            c.calibrated   = ~isempty(fun);
            if c.calibrated
                c.power_mW = slider.Value;
                c.range_mW = [minp maxp];
            else
                c.power_mW = [];
                c.range_mW = [];
            end
        end
    end

    % Component initialization
    methods (Access = private)

        function createComponents(app)
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 560 620];
            app.UIFigure.Name = 'Power Controller (calibrated)';
            % Closing the window deletes the app (releases DAQ + COM4).
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);

            app.GridLayout = uigridlayout(app.UIFigure);
            app.GridLayout.ColumnWidth = {'1x', '1x'};
            % rows: wavelength / slider / readout / shutter / pulse / laser / volt
            app.GridLayout.RowHeight = {'0.7x', '1.4x', '0.4x', '1x', '0.8x', '1x', '0.5x'};

            % --- wavelength labels (row 1) ---
            app.Label900  = uilabel(app.GridLayout);
            app.Label900.HorizontalAlignment = 'center'; app.Label900.FontSize = 50;
            app.Label900.Layout.Row = 1; app.Label900.Layout.Column = 1; app.Label900.Text = '900';

            app.Label1100 = uilabel(app.GridLayout);
            app.Label1100.HorizontalAlignment = 'center'; app.Label1100.FontSize = 50;
            app.Label1100.Layout.Row = 1; app.Label1100.Layout.Column = 2; app.Label1100.Text = '1100';

            % --- mW sliders (row 2). Placeholder Limits are wide; the real range is
            %     set in startupFcn from the LUT (see init_slider). ---
            app.Power900 = uislider(app.GridLayout);
            app.Power900.Limits = [0 10000]; app.Power900.Layout.Row = 2; app.Power900.Layout.Column = 1;
            app.Power900.ValueChangedFcn = createCallbackFcn(app, @Power900ValueChanged, true);

            app.Power1100 = uislider(app.GridLayout);
            app.Power1100.Limits = [0 10000]; app.Power1100.Layout.Row = 2; app.Power1100.Layout.Column = 2;
            app.Power1100.ValueChangedFcn = createCallbackFcn(app, @Power1100ValueChanged, true);

            % --- mW readout labels (row 3) ---
            app.PowerReadout900 = uilabel(app.GridLayout);
            app.PowerReadout900.HorizontalAlignment = 'center'; app.PowerReadout900.FontSize = 18;
            app.PowerReadout900.Layout.Row = 3; app.PowerReadout900.Layout.Column = 1;
            app.PowerReadout900.Text = '-- mW';

            app.PowerReadout1100 = uilabel(app.GridLayout);
            app.PowerReadout1100.HorizontalAlignment = 'center'; app.PowerReadout1100.FontSize = 18;
            app.PowerReadout1100.Layout.Row = 3; app.PowerReadout1100.Layout.Column = 2;
            app.PowerReadout1100.Text = '-- mW';

            % --- shutter toggles (row 4). Start green (= CLOSED). ---
            app.SHUTTER900Button = uibutton(app.GridLayout, 'state');
            app.SHUTTER900Button.Text = 'CLOSED'; app.SHUTTER900Button.FontSize = 26;
            app.SHUTTER900Button.BackgroundColor = app.COLOR_IDLE; app.SHUTTER900Button.FontColor = 'w';
            app.SHUTTER900Button.Layout.Row = 4; app.SHUTTER900Button.Layout.Column = 1;
            app.SHUTTER900Button.ValueChangedFcn = createCallbackFcn(app, @SHUTTER900ButtonValueChanged, true);

            app.SHUTTER1100Button = uibutton(app.GridLayout, 'state');
            app.SHUTTER1100Button.Text = 'CLOSED'; app.SHUTTER1100Button.FontSize = 26;
            app.SHUTTER1100Button.BackgroundColor = app.COLOR_IDLE; app.SHUTTER1100Button.FontColor = 'w';
            app.SHUTTER1100Button.Layout.Row = 4; app.SHUTTER1100Button.Layout.Column = 2;
            app.SHUTTER1100Button.ValueChangedFcn = createCallbackFcn(app, @SHUTTER1100ButtonValueChanged, true);

            % --- momentary pulse buttons (row 5) ---
            app.PULSE900Button = uibutton(app.GridLayout, 'push');
            app.PULSE900Button.Text = 'PULSE 0.5s'; app.PULSE900Button.FontSize = 18;
            app.PULSE900Button.Layout.Row = 5; app.PULSE900Button.Layout.Column = 1;
            app.PULSE900Button.ButtonPushedFcn = createCallbackFcn(app, @PULSE900ButtonPushed, true);

            app.PULSE1100Button = uibutton(app.GridLayout, 'push');
            app.PULSE1100Button.Text = 'PULSE 0.5s'; app.PULSE1100Button.FontSize = 18;
            app.PULSE1100Button.Layout.Row = 5; app.PULSE1100Button.Layout.Column = 2;
            app.PULSE1100Button.ButtonPushedFcn = createCallbackFcn(app, @PULSE1100ButtonPushed, true);

            % --- laser gate toggle (row 6, full width). Start green (= OFF). ---
            app.LASERButton = uibutton(app.GridLayout, 'state');
            app.LASERButton.Text = 'LASER OFF'; app.LASERButton.FontSize = 30;
            app.LASERButton.BackgroundColor = app.COLOR_IDLE; app.LASERButton.FontColor = 'w';
            app.LASERButton.Layout.Row = 6; app.LASERButton.Layout.Column = [1 2];
            app.LASERButton.ValueChangedFcn = createCallbackFcn(app, @LASERButtonValueChanged, true);

            % --- voltage readout (row 7) ---
            app.VoltageLabel = uilabel(app.GridLayout);
            app.VoltageLabel.HorizontalAlignment = 'center'; app.VoltageLabel.FontSize = 20;
            app.VoltageLabel.Layout.Row = 7; app.VoltageLabel.Layout.Column = [1 2];
            app.VoltageLabel.Text = '0.00 V';

            if app.WantVisible
                app.UIFigure.Visible = 'on';
            end
        end
    end

    % App creation and deletion
    methods (Access = public)

        function app = PowerControllerCalibrated(varargin)
            % PowerControllerCalibrated('Simulate', tf, 'Visible', tf)
            %   Simulate (default false): no DAQ/serial, for off-rig testing.
            %   Visible  (default true) : show the window; false = headless,
            %                             for driving it from a remote bridge.
            p = inputParser;
            p.addParameter('Simulate', false, @(x) islogical(x) || isnumeric(x));
            p.addParameter('Visible',  true,  @(x) islogical(x) || isnumeric(x));
            p.parse(varargin{:});

            runningApp = getRunningApp(app);
            if isempty(runningApp)
                app.Simulate    = logical(p.Results.Simulate);
                app.WantVisible = logical(p.Results.Visible);
                createComponents(app)
                registerApp(app, app.UIFigure)
                runStartupFcn(app, @startupFcn)
            else
                figure(runningApp.UIFigure)
                app = runningApp;
            end
            if nargout == 0
                clear app
            end
        end

        function delete(app)
            % Release the DAQ + COM4 serial before tearing down the window, so
            % closing the GUI frees the hardware (otherwise the ports stay held
            % and the next GUI / experiment can't open them).
            try, app.releaseHardware(); catch, end
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                delete(app.UIFigure)
            end
        end
    end
end

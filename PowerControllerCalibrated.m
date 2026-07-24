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
        MAX_LASER_VOLTAGE = 3.5;   % V, gate voltage for max power (HolographicPowerControl.gate_voltage)
        % Status colours: green = safe (shutter closed / laser off), red = live
        % (shutter open / laser on), so state is obvious at a glance.
        COLOR_IDLE   = [0.30 0.65 0.40];   % green
        COLOR_ACTIVE = [0.85 0.16 0.16];   % red
        % LUT paths come from the `power_calibration` struct that the `power_calibrations`
        % script defines (same source patch_experiment.m uses); see startupFcn.
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
    end

    methods (Access = private)

        % ---- DAQ helpers ----------------------------------------------------
        % Output vector order matches the order outputs are added in startupFcn:
        %   [shutter900, shutter1100, laser_voltage]
        function data = build_output(app)
            data = cat(2, app.shutter900, app.shutter1100, app.laser_voltage);
        end

        function open(app, shutter_id)
            data = app.build_output();
            data(shutter_id) = 1;
            app.dq.write(data);
        end

        function close(app, shutter_id)
            data = app.build_output();
            data(shutter_id) = 0;
            app.dq.write(data);
        end

        function write_voltage(app)
            app.dq.write(app.build_output());
            app.VoltageLabel.Text = sprintf('%.2f V', app.laser_voltage);
        end

        function rotate(app, hwp, deg)
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
            if isvalid(app)                      % app may have closed during the pulse
                app.dq.write(app.build_output());  % restore latched shutter states
            end
            delete(t);
        end
    end

    % Callbacks that handle component events
    methods (Access = private)

        function startupFcn(app)
            app.dq = daq('ni');

            s = serialport("COM4", 9600, ...
                'ByteOrder', 'big-endian', 'Parity', 'none', ...
                'StopBits', 1, 'DataBits', 8);
            s.configureTerminator('CR/LF');

            % Shutters (digital) + HWPs (ELL14 on serial). Same wiring/order as
            % PowerControllerSimple: line5=900, line4=1100.
            app.dq.addoutput('Dev1', 'port0/line5', 'Digital');
            app.hwp900 = ELL14(SerialInterface(s), 1, 'hwp');
            app.shutter900 = 0;

            app.dq.addoutput('Dev1', 'port0/line4', 'Digital');
            app.hwp1100 = ELL14(SerialInterface(s), 2, 'hwp');
            app.shutter1100 = 0;

            % Laser gate (analog out). Added LAST so it is the last element of the
            % output vector (see build_output). ao1 as in SimpleVoltageController.
            app.dq.addoutput('Dev1', 'ao1', 'Voltage');
            app.laser_voltage = 0;

            % Pull the per-laser LUT paths from the `power_calibration` struct the
            % `power_calibrations` script defines (same source as patch_experiment.m /
            % default_setup.m). Run it here so the app is self-contained.
            power_calibrations;   % defines `power_calibration` in this workspace

            % Load calibrations (mW -> HWP degrees) and point each slider at its range.
            [app.pwr_fun900,  app.min_pwr900,  app.max_pwr900]  = app.load_lut(power_calibration.calibration_900);
            [app.pwr_fun1100, app.min_pwr1100, app.max_pwr1100] = app.load_lut(power_calibration.calibration_1100);
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
    end

    % Component initialization
    methods (Access = private)

        function createComponents(app)
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 560 620];
            app.UIFigure.Name = 'Power Controller (calibrated)';

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

            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        function app = PowerControllerCalibrated
            runningApp = getRunningApp(app);
            if isempty(runningApp)
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
            delete(app.UIFigure)
        end
    end
end

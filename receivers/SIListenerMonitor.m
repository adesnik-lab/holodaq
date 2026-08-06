classdef SIListenerMonitor < handle
    %SILISTENERMONITOR Status window for the async SI listener: lamp + Start/Stop.
    %   start_si_listener pops one of these up. It exists because the async
    %   listener is INVISIBLE at the prompt: three states look identical unless
    %   you remember to type r.status() (and still hold r) --
    %
    %       green  LISTENING   polling on schedule, ScanImage is being primed
    %       amber  STARVED     running, but something is blocking the prompt, so
    %                          primes are late (Receiver.listen_async, note 1)
    %       red    STOPPED     not polling -- either you stopped it, or the poll
    %                          timer errored (Receiver.on_timer_error) and the
    %                          listener died while still looking started
    %       grey   NO LISTENER / DISPLAY STALLED -- the window itself is not live
    %
    %   CLOSING THE WINDOW STOPS THE LISTENER. This is the on/off control, not a
    %   passive monitor, so the X de-arms ScanImage; delete() prints a line saying
    %   so, because a silently de-armed rig is the expensive failure here.
    %
    %   Usage:
    %       start_si_listener                     % window opens with the listener
    %       start_si_listener('nogui')            % listener only, no window
    %       SIListenerMonitor(r)                  % re-open over a receiver you hold
    %       SIListenerMonitor(r, 'Visible', false)   % off-screen, for tests
    %
    %   Works over any Receiver (the tests drive a CountingReceiver), not just
    %   SIReceiver -- it only reads the poll timer and asks before touching
    %   SIReceiver-only properties.
    %
    %   See also start_si_listener, Receiver/listen_async, Receiver/stop,
    %   Receiver/status, test_si_listener_monitor.

    properties (SetAccess = private)
        Receiver          % the Receiver being watched
        UIFigure
        Lamp
        StateLabel
        ToggleButton
        PollLabel
        PrimeLabel
        RootLabel
        Refresh           % display timer ([] once stopped)
    end

    properties (Access = private)
        % Baseline for the achieved-period estimate: the poll timer's tick count
        % and a stopwatch id from the previous refresh. [] means "no baseline yet".
        LastTasks = []
        LastClock = []
    end

    properties (Constant)
        % Lamp colours: green safe / red live is the convention
        % PowerControllerCalibrated already uses, so a rig operator reads the same
        % two colours the same way on both windows.
        COLOR_OK      = [0.30 0.65 0.40]
        COLOR_STARVED = [0.93 0.69 0.13]
        COLOR_STOPPED = [0.85 0.16 0.16]
        COLOR_NONE    = [0.60 0.60 0.60]
        % Button colours from the launcher's Start/Abort pair.
        BTN_STOP  = [0.85 0.33 0.31]
        BTN_START = [0.20 0.55 0.95]
        DIM_TEXT  = [0.45 0.45 0.45]
        % 1 s, deliberately NOT the listener's 0.25 s poll period: a faster lamp
        % tells you nothing, and this timer shares the event queue whose
        % congestion is exactly what STARVED reports.
        REFRESH_PERIOD = 1
        TIMER_NAME = 'siListenerMonitor'
        FIG_NAME   = 'SI Listener'
    end

    methods
        function app = SIListenerMonitor(r, varargin)
            assert(nargin >= 1 && ~isempty(r) && isa(r, 'Receiver') && isvalid(r), ...
                'SIListenerMonitor:badReceiver', ...
                ['SIListenerMonitor needs the Receiver handle start_si_listener ' ...
                 'returned: SIListenerMonitor(r).']);

            p = inputParser();
            p.addParameter('Visible', true, @(v) islogical(v) || isnumeric(v));
            p.parse(varargin{:});

            app.Receiver = r;
            % Take over from any previous window BEFORE building ours, so the
            % sweep cannot eat the window we are about to create.
            SIListenerMonitor.closeStaleMonitors();
            app.buildUI(logical(p.Results.Visible));
            app.refresh();            % paint a real state before the first tick
            % Realizing a uifigure blocks the event queue for a second or two, which
            % genuinely starves the listener -- but blaming the listener for a stall
            % this window just caused is a false amber on every single launch. Let
            % the figure finish, then start timing from a quiet prompt.
            drawnow
            app.resetTickBaseline();
            app.startRefreshTimer();
        end

        function delete(app)
            % Closing the window stops the listener. Deliberate, and announced:
            % this de-arms ScanImage, and the whole point of the window is that
            % the listener's state is never a surprise.
            app.stopRefreshTimer();
            r = app.Receiver;
            stopped = false;
            if ~isempty(r) && isvalid(r) && ~isempty(r.poll) && isvalid(r.poll)
                try
                    r.stop();
                    stopped = true;
                catch
                end
            end
            if stopped
                fprintf(['[%s] status window closed -> async listener STOPPED. ' ...
                         'Restart with start_si_listener.\n'], r.name);
            end
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                app.UIFigure.CloseRequestFcn = '';   % already tearing down
                delete(app.UIFigure);
            end
        end

        function detach(app)
            %DETACH Tear this window down WITHOUT stopping the listener.
            %   Only for handing over to a replacement window; a normal close
            %   goes through delete(), which does stop it.
            app.stopRefreshTimer();
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                app.UIFigure.CloseRequestFcn = '';
                delete(app.UIFigure);
            end
            % Drop the receiver so a later destructor call on this dead app
            % cannot reach in and stop the listener the new window owns.
            app.Receiver = [];
        end

        function refresh(app)
            %REFRESH Re-read the poll timer and repaint. Never throws.
            %   Under a timer an escaping error stops the timer, which would
            %   freeze the lamp on a stale reading -- a window still saying
            %   LISTENING after the listener died is worse than no window.
            if isempty(app.UIFigure) || ~isvalid(app.UIFigure), return; end
            try
                [state, period, achieved] = app.readReceiver();
                app.applyState(state, period, achieved);
            catch err
                app.Lamp.Color = app.COLOR_NONE;
                app.StateLabel.Text = 'DISPLAY ERROR';
                app.PollLabel.Text = err.message;
            end
            drawnow limitrate
        end

        function tf = isListening(app)
            r = app.Receiver;
            tf = ~isempty(r) && isvalid(r) && ~isempty(r.poll) && isvalid(r.poll) ...
                 && strcmp(r.poll.Running, 'on');
        end

        function onToggle(app)
            r = app.Receiver;
            if isempty(r) || ~isvalid(r), return; end
            try
                if app.isListening()
                    r.stop();
                else
                    r.listen_async();
                end
            catch err
                % A callback must not throw into the event queue; show it instead.
                app.StateLabel.Text = 'ERROR';
                app.PollLabel.Text = err.message;
                return
            end
            app.refresh();   % the lamp agrees with the click now, not in a second
        end

        function onRefreshError(app, src)
            %ONREFRESHERROR ErrorFcn for the display timer. Public like
            %   Receiver.on_timer_error, and for the same reason: it is the only way
            %   to exercise the dead-display path from a test.
            %
            %   refresh() catches everything, so reaching here means the display is
            %   dead. DELETE both handles rather than dropping them -- an orphaned
            %   timer is the zombie Receiver.on_timer_error exists to prevent, one
            %   level down. Then say the window is stale: a frozen lamp still
            %   reading LISTENING is the one outcome worse than no lamp at all.
            for h = {src, app.Refresh}
                t = h{1};
                if ~isempty(t) && isa(t, 'timer') && isvalid(t)
                    try, stop(t);   catch, end
                    try, delete(t); catch, end
                end
            end
            app.Refresh = [];
            if ~isempty(app.Lamp) && isvalid(app.Lamp)
                app.Lamp.Color = app.COLOR_NONE;
                app.StateLabel.Text = 'DISPLAY STALLED';
                app.PollLabel.Text = 'refresh timer died; this window is no longer live';
            end
        end
    end

    methods (Static)
        function state = stateFrom(alive, running, period, achieved)
            %STATEFROM Lamp state from the numbers the poll timer exposes.
            %   Static and pure so the truth table is testable off the rig:
            %   timer.AveragePeriod is read-only, so a starved listener cannot be
            %   staged by driving a real timer.
            if ~alive
                state = 'none';
            elseif ~running
                state = 'stopped';
            elseif ~isnan(achieved) && achieved > 3 * period
                % The same 3x rule Receiver.status prints STARVED for -- one
                % threshold, not two that can disagree with each other.
                state = 'starved';
            else
                state = 'listening';
            end
        end

        function closeStaleMonitors()
            %CLOSESTALEMONITORS One window, one display timer.
            %   The rule listen_async enforces for poll timers, applied to the
            %   display: running start_si_listener twice must not leave a dead
            %   window ticking beside the live one.
            figs = findall(groot, 'Type', 'figure', 'Name', SIListenerMonitor.FIG_NAME);
            for i = 1:numel(figs)
                f = figs(i);
                old = f.UserData;
                if isa(old, 'SIListenerMonitor') && isvalid(old)
                    try, old.detach(); catch, end   % detach, NOT delete: keep the listener up
                end
                if isvalid(f)
                    f.CloseRequestFcn = '';
                    delete(f);
                end
            end
            % Orphans whose app object is already gone: the timer is all that
            % is left of them, and it is invisible except through timerfindall.
            ts = timerfindall('Name', SIListenerMonitor.TIMER_NAME);
            for i = 1:numel(ts)
                t = ts(i);
                if isvalid(t)
                    try, stop(t);   catch, end
                    try, delete(t); catch, end
                end
            end
        end
    end

    methods (Access = private)
        function buildUI(app, visible)
            app.UIFigure = uifigure('Name', app.FIG_NAME, ...
                'Position', [100 100 400 150], 'Resize', 'off', ...
                'Visible', local_onoff(visible));
            app.UIFigure.CloseRequestFcn = @(s, e) delete(app);
            % Makes the window (and so the app) findable again from the prompt:
            % findall(0, 'Name', 'SI Listener').UserData
            app.UIFigure.UserData = app;

            main = uigridlayout(app.UIFigure, [2 1]);
            main.RowHeight   = {'fit', 'fit'};
            main.ColumnWidth = {'1x'};
            main.RowSpacing  = 12;
            main.Padding     = [12 12 12 12];

            % Row 1: lamp, state word, one toggle button
            top = uigridlayout(main, [1 3]);
            top.ColumnWidth   = {24, '1x', 90};
            top.ColumnSpacing = 8;
            top.Padding       = [0 0 0 0];
            app.Lamp = uilamp(top, 'Color', app.COLOR_NONE);
            app.StateLabel = uilabel(top, 'Text', '', 'FontWeight', 'bold');
            app.ToggleButton = uibutton(top, 'Text', 'Stop', ...
                'FontColor', [1 1 1], 'FontWeight', 'bold', ...
                'BackgroundColor', app.BTN_STOP, ...
                'ButtonPushedFcn', @(s, e) app.onToggle());

            % Row 2: the three detail lines
            det = uigridlayout(main, [3 2]);
            det.RowHeight    = {'fit', 'fit', 'fit'};
            det.ColumnWidth  = {40, '1x'};
            det.RowSpacing   = 2;
            det.ColumnSpacing = 6;
            det.Padding      = [0 0 0 0];
            app.PollLabel  = app.detailRow(det, 'poll');
            app.PrimeLabel = app.detailRow(det, 'prime');
            app.RootLabel  = app.detailRow(det, 'root');
        end

        function lbl = detailRow(app, parent, name)
            uilabel(parent, 'Text', name, 'FontColor', app.DIM_TEXT, 'FontSize', 11);
            lbl = uilabel(parent, 'Text', '', 'FontColor', app.DIM_TEXT, 'FontSize', 11);
        end

        function [state, period, achieved] = readReceiver(app)
            r = app.Receiver;
            alive = false; running = false;
            period = NaN; achieved = NaN;
            if ~isempty(r) && isvalid(r)
                alive = true;
                period = r.poll_period;
                % Read the timer directly, NOT r.status(): status() prints a line
                % on every call, and at 1 Hz that buries the command window the
                % listener also reports primes and errors on.
                if ~isempty(r.poll) && isvalid(r.poll)
                    running  = strcmp(r.poll.Running, 'on');
                    achieved = app.tickRate(r);
                end
            end
            if ~running
                app.resetTickBaseline();   % a restart must not be timed against this
            end
            state = SIListenerMonitor.stateFrom(alive, running, period, achieved);
        end

        function resetTickBaseline(app)
            app.LastTasks = [];
            app.LastClock = [];
        end

        function achieved = tickRate(app, r)
            %TICKRATE Achieved poll period over the ticks SINCE THE LAST REFRESH.
            %   Deliberately not timer.AveragePeriod, which Receiver.status uses:
            %   that average is cumulative over the timer's whole life, so one
            %   early stall (building this very window is enough) biases it for
            %   good and leaves an amber lamp long after the listener recovered --
            %   while a long healthy run washes out a stall happening right now.
            %   A lamp has to mean now, so measure the recent interval instead.
            achieved = NaN;
            n = r.poll.TasksExecuted;
            if ~isempty(app.LastClock)
                elapsed = toc(app.LastClock);
                delta   = n - app.LastTasks;
                % delta < 0 means the timer was restarted under us: re-baseline
                % rather than report nonsense. And give it at least a couple of
                % periods' worth of elapsed time before passing any verdict.
                if delta >= 0 && elapsed >= 2 * r.poll_period
                    % delta == 0 -> Inf: not one tick in that whole window, which
                    % is starvation in its most severe form, not a missing reading.
                    achieved = elapsed / delta;
                end
            end
            app.LastTasks = n;
            app.LastClock = tic;
        end

        function applyState(app, state, period, achieved)
            switch state
                case 'listening'
                    app.Lamp.Color = app.COLOR_OK;
                    app.StateLabel.Text = 'LISTENING';
                case 'starved'
                    app.Lamp.Color = app.COLOR_STARVED;
                    app.StateLabel.Text = 'STARVED';
                case 'stopped'
                    app.Lamp.Color = app.COLOR_STOPPED;
                    app.StateLabel.Text = 'STOPPED';
                case 'none'
                    app.Lamp.Color = app.COLOR_NONE;
                    app.StateLabel.Text = 'NO LISTENER';
            end

            if any(strcmp(state, {'listening', 'starved'}))
                app.ToggleButton.Text = 'Stop';
                app.ToggleButton.BackgroundColor = app.BTN_STOP;
            else
                app.ToggleButton.Text = 'Start';
                app.ToggleButton.BackgroundColor = app.BTN_START;
            end
            app.ToggleButton.Enable = local_onoff(~strcmp(state, 'none'));

            app.PollLabel.Text  = app.pollText(state, period, achieved);
            app.PrimeLabel.Text = app.primeText();
            app.RootLabel.Text  = app.rootText();
        end

        function s = pollText(app, state, period, achieved)  %#ok<INUSD>
            if isnan(period)
                s = '—';
                return
            end
            if isnan(achieved)
                s = sprintf('%.2f s target / — achieved', period);
            elseif isinf(achieved)
                s = sprintf('%.2f s target / NOT TICKING', period);
            else
                s = sprintf('%.2f s target / %.2f s achieved', period, achieved);
            end
            if strcmp(state, 'starved')
                s = [s '   something is blocking the prompt'];
            end
        end

        function s = primeText(app)
            r = app.Receiver;
            s = '—';
            if isempty(r) || ~isvalid(r), return; end
            stem = r.stem();
            if strcmp(stem, '?')
                % No stem but a finite seq is the normal state at startup:
                % flush_stale adopts whatever prime is already on the channel as
                % its baseline WITHOUT running it, so that seq is a prime this
                % listener has deliberately not served. Say that, rather than
                % showing a bare '?' next to a number and letting it read as a
                % prime that happened.
                if isinf(r.last_prime_seq)
                    s = 'nothing yet';
                else
                    s = sprintf('nothing yet (channel at seq %g)', r.last_prime_seq);
                end
                return
            end
            s = sprintf('%s   (seq %g)', stem, r.last_prime_seq);
        end

        function s = rootText(app)
            % si_root is SIReceiver's, not Receiver's, and the source string it
            % resolved from is only printed, never stored -- so this is the path
            % alone, not an invented provenance.
            r = app.Receiver;
            s = '—';
            if ~isempty(r) && isvalid(r) && isprop(r, 'si_root')
                s = char(r.si_root);
            end
        end

        function startRefreshTimer(app)
            app.Refresh = timer('Name', app.TIMER_NAME, ...
                'ExecutionMode', 'fixedSpacing', ...  % space AFTER the callback, as the
                'BusyMode', 'drop', ...               % listener's own poll timer does
                'Period', app.REFRESH_PERIOD, ...
                'StartDelay', app.REFRESH_PERIOD, ...  % start() fires at once otherwise,
                ...                                    % sampling an interval of zero
                'TimerFcn', @(~, ~) app.refresh(), ...
                'ErrorFcn', @(src, ~) app.onRefreshError(src));
            start(app.Refresh);
        end

        function stopRefreshTimer(app)
            if ~isempty(app.Refresh) && isvalid(app.Refresh)
                try, stop(app.Refresh);   catch, end
                try, delete(app.Refresh); catch, end
            end
            app.Refresh = [];
        end

    end
end

function s = local_onoff(tf)
    % Char 'on'/'off' rather than a logical: accepted by every release that has
    % uifigure, unlike the logical shorthand.
    if tf, s = 'on'; else, s = 'off'; end
end

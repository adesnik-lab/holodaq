function test_si_listener_monitor()
%TEST_SI_LISTENER_MONITOR  The SI listener status window. Offline, no rig, no broker.
%
%   >> addpath(genpath(<holodaq>)); addpath(fullfile(<holodaq>,'tests'));
%   >> test_si_listener_monitor
%
%   Windows are built with 'Visible', false so this runs unattended. The cases are
%   the ways a status light can lie: showing LISTENING for a listener that stopped,
%   showing green for one that is starved, a second window ticking beside the live
%   one, and a torn-down window leaving an orphaned timer behind.
%
%   See also SIListenerMonitor, test_receiver_async, CountingReceiver.

    % --- 1. 'gui' / 'nogui' argument forms --------------------------------------
    % Every previously valid invocation must keep meaning what it meant, so the
    % default is a window and the old two-output call site is untouched.
    cases = { ...
        {},                       '',   'async',    true  ; ...
        {'E:'},                   'E:', 'async',    true  ; ...
        {'nogui'},                '',   'async',    false ; ...
        {'gui'},                  '',   'async',    true  ; ...
        {'NOGUI'},                '',   'async',    false ; ...   % case-insensitive
        {'  nogui  '},            '',   'async',    false ; ...   % whitespace-tolerant
        {'nogui', 'E:'},          'E:', 'async',    false ; ...   % order-insensitive
        {'E:', 'nogui'},          'E:', 'async',    false ; ...
        {'E:', 'blocking', 'nogui'}, 'E:', 'blocking', false ; ...
        {"nogui"},                '',   'async',    false };      % string, not char

    for i = 1:size(cases, 1)
        [root, mode, gui] = parse_si_listener_args(cases{i, 1}{:});
        assert(strcmp(root, cases{i, 2}), 'case %d: root "%s", want "%s"', ...
            i, root, cases{i, 2});
        assert(strcmp(mode, cases{i, 3}), 'case %d: mode "%s", want "%s"', ...
            i, mode, cases{i, 3});
        assert(islogical(gui) && gui == cases{i, 4}, ...
            'case %d: gui %d, want %d', i, gui, cases{i, 4});
    end

    % last keyword wins, so a scripted override can append one
    [~, ~, gui] = parse_si_listener_args('nogui', 'gui');
    assert(gui, 'the last gui keyword should win');

    % the pre-existing two-output call site must be unaffected by the new output
    [root, mode] = parse_si_listener_args('E:', 'blocking');
    assert(strcmp(root, 'E:') && strcmp(mode, 'blocking'), ...
        'adding a third output broke the two-output form');

    % --- 2. stateFrom truth table ------------------------------------------------
    % A pure static function precisely because timer.AveragePeriod is read-only:
    % a starved listener cannot be staged by driving a real timer.
    st = @SIListenerMonitor.stateFrom;
    assert(strcmp(st(false, false, NaN,  NaN),  'none'), 'no receiver -> none');
    assert(strcmp(st(true,  false, 0.25, NaN),  'stopped'), 'not running -> stopped');
    assert(strcmp(st(true,  true,  0.25, 0.26), 'listening'), 'on schedule -> listening');
    assert(strcmp(st(true,  true,  0.25, NaN),  'listening'), ...
        'a timer that has not yet averaged must not read as starved');
    assert(strcmp(st(true,  true,  0.25, 1.00), 'starved'), '4x the period -> starved');
    assert(strcmp(st(true,  true,  0.25, 0.74), 'listening'), ...
        'just under 3x must stay green (same threshold as Receiver.status)');
    assert(strcmp(st(true,  true,  0.25, 0.76), 'starved'), 'just over 3x -> starved');
    assert(strcmp(st(true,  true,  0.25, Inf),  'starved'), ...
        'Inf is "not one tick in the whole window" -- the worst starvation, not a gap');

    % --- 3. the lamp tracks a live listener --------------------------------------
    r = CountingReceiver('mon1');
    r.poll_period = 0.05;
    cleanR = onCleanup(@() r.stop());
    r.listen_async();
    app = SIListenerMonitor(r, 'Visible', false);
    cleanApp = onCleanup(@() delete(app));
    % Drive refresh() by hand from here on, so the achieved-period samples below
    % are not re-baselined by the window's own 1 Hz timer firing mid-test.
    stop(app.Refresh);

    assert(strcmp(app.StateLabel.Text, 'LISTENING'), ...
        'a running listener must read LISTENING, got "%s"', app.StateLabel.Text);
    assert(isequal(app.Lamp.Color, SIListenerMonitor.COLOR_OK), 'lamp must be green');
    assert(strcmp(app.ToggleButton.Text, 'Stop'), ...
        'the button must offer Stop while listening, got "%s"', app.ToggleButton.Text);

    % A healthy listener must STAY green. It did not when the achieved period came
    % from timer.AveragePeriod: building this window stalls the queue, and a
    % cumulative average keeps that first stall forever, so the lamp sat on amber
    % for a listener that was ticking perfectly. Hence tickRate's recent-interval
    % measurement -- this is that regression.
    % Two refreshes: the first only baselines the tick counter (the constructor
    % deliberately drops its baseline once the figure is realized), the second
    % measures the interval between them.
    app.refresh();
    pause(0.4);          % ~8 ticks at a 0.05 s period
    app.refresh();
    assert(strcmp(app.StateLabel.Text, 'LISTENING'), ...
        ['a healthy listener must stay green across refreshes; got "%s" (%s). An ' ...
         'early stall must not stick.'], app.StateLabel.Text, app.PollLabel.Text);
    achieved = sscanf(app.PollLabel.Text, '%f s target / %f s achieved');
    assert(numel(achieved) == 2 && achieved(2) < 3 * r.poll_period, ...
        'the poll line must report a real, healthy achieved period, got "%s"', ...
        app.PollLabel.Text);

    % it must follow the listener rather than latch: this is the failure that makes
    % a status light worse than none.
    r.stop();
    app.refresh();
    assert(strcmp(app.StateLabel.Text, 'STOPPED'), ...
        'the window must notice a stopped listener, got "%s"', app.StateLabel.Text);
    assert(isequal(app.Lamp.Color, SIListenerMonitor.COLOR_STOPPED), 'lamp must be red');
    assert(strcmp(app.ToggleButton.Text, 'Start'), 'the button must offer Start');

    % --- 4. the button round-trips, leaving one poll timer -----------------------
    app.onToggle();                       % Start
    assert(app.isListening(), 'Start must restart the listener');
    assert(strcmp(app.StateLabel.Text, 'LISTENING'), ...
        'the lamp must agree with the click immediately, not on the next refresh');
    assert(numel(timerfindall('Name', 'mon1Receiver')) == 1, ...
        'Start must leave exactly one poll timer, found %d', ...
        numel(timerfindall('Name', 'mon1Receiver')));
    app.onToggle();                       % Stop
    assert(~app.isListening(), 'Stop must halt the listener');
    assert(isempty(timerfindall('Name', 'mon1Receiver')), 'Stop must delete the poll timer');
    app.onToggle();                       % Start again, for the details below
    assert(app.isListening());

    % --- 5. detail lines ---------------------------------------------------------
    stub = r.interface;
    stub.post('mon1', struct('prime_seq', 7, 'stem', '260806_M1_1x'));
    ok = wait_for(@() r.n_run >= 1, 3);
    assert(ok, 'async listener never primed within 3 s');
    app.refresh();
    assert(contains(app.PrimeLabel.Text, '260806_M1_1x') ...
        && contains(app.PrimeLabel.Text, 'seq 7'), ...
        'the prime line must show the stem and seq, got "%s"', app.PrimeLabel.Text);
    assert(contains(app.PollLabel.Text, 'target'), ...
        'the poll line must report the target period, got "%s"', app.PollLabel.Text);
    % si_root belongs to SIReceiver, not Receiver -- over a plain Receiver the line
    % must degrade, not error.
    assert(strcmp(app.RootLabel.Text, '—'), ...
        'a receiver with no si_root must show a dash, got "%s"', app.RootLabel.Text);

    % --- 6. one window, one display timer ----------------------------------------
    % Running start_si_listener twice must not leave a dead window ticking beside
    % the live one -- the rule listen_async already enforces for poll timers.
    app2 = SIListenerMonitor(r, 'Visible', false);
    cleanApp2 = onCleanup(@() delete(app2));
    assert(numel(findall(groot, 'Type', 'figure', 'Name', SIListenerMonitor.FIG_NAME)) == 1, ...
        'a second window must take over, not stack');
    assert(numel(timerfindall('Name', SIListenerMonitor.TIMER_NAME)) == 1, ...
        'a second window must leave exactly one refresh timer, found %d', ...
        numel(timerfindall('Name', SIListenerMonitor.TIMER_NAME)));
    % ...and the handover must NOT stop the listener it is watching
    assert(app2.isListening(), 'taking over a window must not stop the listener');
    assert(isempty(app.Refresh), 'the superseded window must have released its timer');

    % --- 7. closing the window stops the listener, and leaves no orphans ---------
    % This is the deliberate contract (the window is the on/off control), and the
    % orphan check is the zombie-timer guard from test_receiver_async, one level up.
    delete(app2);
    assert(isempty(r.poll), 'closing the window must stop the listener');
    assert(isempty(timerfindall('Name', 'mon1Receiver')), 'no orphaned poll timer');
    assert(isempty(timerfindall('Name', SIListenerMonitor.TIMER_NAME)), ...
        'no orphaned refresh timer');
    assert(isempty(findall(groot, 'Type', 'figure', 'Name', SIListenerMonitor.FIG_NAME)), ...
        'the figure must be gone');

    % --- 8. a window over a dead receiver says so, rather than lying -------------
    r9 = CountingReceiver('mon9');
    app9 = SIListenerMonitor(r9, 'Visible', false);
    clean9 = onCleanup(@() delete(app9));
    assert(strcmp(app9.StateLabel.Text, 'STOPPED'), ...
        'a receiver that was never started reads STOPPED, got "%s"', app9.StateLabel.Text);
    delete(r9);
    app9.refresh();       % must not throw on a deleted receiver
    assert(strcmp(app9.StateLabel.Text, 'NO LISTENER'), ...
        'a deleted receiver must read NO LISTENER, got "%s"', app9.StateLabel.Text);
    assert(strcmp(app9.ToggleButton.Enable, 'off'), ...
        'nothing to start or stop -> the button must be disabled');

    % --- 9. a dead display timer is visible, not a frozen lamp -------------------
    r10 = CountingReceiver('mon10');
    r10.poll_period = 0.05;
    r10.listen_async();
    app10 = SIListenerMonitor(r10, 'Visible', false);
    clean10 = onCleanup(@() delete(app10));
    app10.onRefreshError([]);
    assert(strcmp(app10.StateLabel.Text, 'DISPLAY STALLED'), ...
        'a dead refresh timer must say so, got "%s"', app10.StateLabel.Text);
    assert(isempty(timerfindall('Name', SIListenerMonitor.TIMER_NAME)), ...
        'the errored refresh timer must be deleted, not orphaned');
    assert(app10.isListening(), 'a dead display must not take the listener down with it');
    r10.stop();

    clear cleanR cleanApp cleanApp2 clean9 clean10  %#ok<CLEAR>
    fprintf(['PASS test_si_listener_monitor (nogui parsing, lamp truth table, ' ...
             'lamp follows the listener, toggle round-trip, one window, ' ...
             'close stops the listener, no orphaned timers).\n']);
end

function ok = wait_for(pred, timeout)
    % pause() lets the timer callback run -- this is what the prompt does when idle
    t0 = tic; ok = false;
    while toc(t0) < timeout
        if pred(), ok = true; return, end
        pause(0.02);
    end
end

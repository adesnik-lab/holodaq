function test_receiver_async()
%TEST_RECEIVER_ASYNC  Offline tests for the async listener. No rig, no broker.
%
%   >> addpath(fullfile(pwd,'tests')); addpath(genpath(pwd)); test_receiver_async
%
%   Covers what the timer makes newly possible to get wrong: a duplicate listener,
%   a listener that stopped silently, and tick() letting an error escape (which
%   under a timer STOPS it). Also checks tick() still behaves identically to the
%   old inline loop body, since listen() now drives it too.

    r = CountingReceiver('test');
    stub = r.interface;

    % --- 1. tick() primes once per NEW prime_seq, never on a re-read -------------
    stub.post('test', struct('prime_seq', 1, 'stem', '260805_M1_1x'));
    r.tick();
    assert(r.n_run == 1, 'a new prime must call run(), got %d', r.n_run);
    r.tick(); r.tick();
    assert(r.n_run == 1, 'a re-read of the same prime_seq must NOT re-run');
    stub.post('test', struct('prime_seq', 2, 'stem', '260805_M1_2x'));
    r.tick();
    assert(r.n_run == 2, 'a higher prime_seq must re-run');
    assert(strcmp(r.stem(), '260805_M1_2x'), 'stem should track the newest prime');

    % acks: one per prime, on config/<name>_status, and ok=true
    ack_topics = cellfun(@(a) a.topic, stub.acks, 'UniformOutput', false);
    assert(all(strcmp(ack_topics, 'test_status')), 'acks must go to <name>_status');
    assert(stub.acks{end}.data.ok, 'a successful prime must ack ok=true');

    % --- 2. a throwing run() acks false and does NOT escape tick() ---------------
    r2 = CountingReceiver('t2'); s2 = r2.interface;
    r2.run_throws = true;
    s2.post('t2', struct('prime_seq', 1, 'stem', 'x'));
    r2.tick();     % must not throw
    assert(r2.n_run == 1);
    assert(~s2.acks{end}.data.ok, 'a failed prime must ack ok=false');

    % --- 3. THE TIMER-CRITICAL ONE: a throwing poll must not escape tick() -------
    % Unguarded, this killed listen()'s while loop; under a timer it stops the timer.
    r3 = CountingReceiver('t3');
    r3.interface.throw_on_scan = true;
    r3.tick();     % must not throw
    r3.tick();
    assert(r3.n_run == 0, 'no prime should be claimed when polling fails');

    % --- 4. abort / finish fire once on a RISING seq, and baseline on first sight -
    r4 = CountingReceiver('t4'); s4 = r4.interface;
    s4.post('abort', struct('abort_seq', 5));
    s4.post('t4_finish', struct('finish_seq', 7));
    r4.tick();
    assert(r4.n_abort == 0 && r4.n_finish == 0, ...
        'first sighting must baseline, not fire (a stale abort must not abort)');
    s4.post('abort', struct('abort_seq', 6));
    s4.post('t4_finish', struct('finish_seq', 8));
    r4.tick();
    assert(r4.n_abort == 1 && r4.n_finish == 1, 'a rising seq must fire exactly once');
    r4.tick();
    assert(r4.n_abort == 1 && r4.n_finish == 1, 'an unchanged seq must not re-fire');

    % --- 5. listen_async: timer starts, ticks, and status() reports it -----------
    r5 = CountingReceiver('t5'); s5 = r5.interface;
    r5.poll_period = 0.05;
    t = r5.listen_async();
    cleanup = onCleanup(@() r5.stop());
    assert(isvalid(t) && strcmp(t.Running, 'on'), 'timer must be running');
    st = r5.status();
    assert(st.running && strcmp(st.mode, 'async'), 'status must report async+running');

    % it must actually prime while we sit at "the prompt" (pause services the queue)
    s5.post('t5', struct('prime_seq', 1, 'stem', 'async_ok'));
    ok = wait_for(@() r5.n_run >= 1, 3);
    assert(ok, 'async listener never primed within 3 s (timer not firing)');
    assert(strcmp(r5.stem(), 'async_ok'));

    % --- 6. no duplicate listeners: listen_async twice leaves ONE timer ----------
    before = numel(timerfindall('Name', 't5Receiver'));
    assert(before == 1, 'expected exactly 1 timer, found %d', before);
    r5.listen_async();
    after = numel(timerfindall('Name', 't5Receiver'));
    assert(after == 1, ...
        ['listen_async must stop the previous timer first -- found %d. Two pollers ' ...
         'would both prime the same box.'], after);

    % --- 7. stop() halts and is idempotent; status() then says so ----------------
    r5.stop();
    assert(isempty(r5.poll), 'stop() must clear the handle');
    assert(isempty(timerfindall('Name', 't5Receiver')), 'stop() must delete the timer');
    r5.stop();   % no-op, must not error
    st = r5.status();
    assert(~st.running && strcmp(st.mode, 'not running'), 'status must report stopped');

    % --- 8. a stopped timer is visible, not silent -------------------------------
    % on_timer_error is the backstop for anything that escapes tick(); it must clear
    % the handle and warn, so status() cannot claim to be listening.
    r6 = CountingReceiver('t6');
    r6.poll_period = 0.05;
    r6.listen_async();
    w = warning('off', 'Receiver:asyncStopped');
    restore = onCleanup(@() warning(w));
    lastwarn('');
    r6.on_timer_error([], []);
    [~, wid] = lastwarn();
    assert(strcmp(wid, 'Receiver:asyncStopped'), ...
        'a stopped async listener must warn, got "%s"', wid);
    st = r6.status();
    assert(~st.running, 'status must not claim to be listening after a timer error');
    % ...and it must DELETE the timer, not merely drop the handle. Dropping it leaves
    % a running orphan that timerfindall still sees, status() cannot see, and a later
    % listen_async() cannot stop -- the zombie this lifecycle exists to prevent.
    assert(isempty(timerfindall('Name', 't6Receiver')), ...
        'on_timer_error left an orphaned timer running');
    r6.stop();

    % --- 9. BusyMode drop: a slow run() must not build a backlog ----------------
    % SIReceiver.run re-arms ScanImage and onFinish can hold a tick up to 60 s, so
    % ticks must never queue behind one another.
    r7 = CountingReceiver('t7'); s7 = r7.interface;
    r7.poll_period = 0.02;
    r7.run_delay = 0.30;              % one prime takes 15 poll periods
    r7.listen_async();
    c7 = onCleanup(@() r7.stop());
    assert(strcmp(r7.poll.ExecutionMode, 'fixedSpacing'), 'must space AFTER the callback');
    assert(strcmp(r7.poll.BusyMode, 'drop'), 'must drop, not queue');
    s7.post('t7', struct('prime_seq', 1, 'stem', 'slow'));
    wait_for(@() r7.n_run >= 1, 3);
    pause(0.5);
    assert(r7.n_run == 1, ...
        'a slow prime must run ONCE, not once per dropped tick (got %d)', r7.n_run);
    r7.stop();

    fprintf(['PASS test_receiver_async (prime once per seq, errors contained, ' ...
             'abort/finish baseline, no duplicate timers, stop idempotent, ' ...
             'stopped-timer visible, slow prime not re-entered).\n']);
end

function ok = wait_for(pred, timeout)
    % pause() lets the timer callback run -- this is what the prompt does when idle
    t0 = tic; ok = false;
    while toc(t0) < timeout
        if pred(), ok = true; return, end
        pause(0.02);
    end
end

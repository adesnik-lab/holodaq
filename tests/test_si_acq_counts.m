function test_si_acq_counts()
%TEST_SI_ACQ_COUNTS  Offline tests for the # Frames / # Volumes guard. No ScanImage.
%
%   >> addpath(genpath(<holodaq>)); test_si_acq_counts
%
%   The rig symptom: the operator sets # Frames in ScanImage's Main Controls, presses
%   Enter (so the value IS committed to the model), and the acquisition still runs with
%   the PREVIOUS grab's value. Nothing in these repos writes framesPerSlice, so the
%   prime must be re-deriving it -- writing hStackManager.enable re-runs the
%   StackManager setters, which is what FakeStackManager.couple reproduces.

    % SIReceiver's constructor calls rig_remote_get, which can reach the network; the
    % guard methods do not need a constructed receiver's rig state, so build one with
    % an explicit root to keep it offline and deterministic.
    r = SIReceiver('D:');
    sm = FakeStackManager();
    r.hSI = struct('hStackManager', sm);

    % --- 1. getAcqCounts reads all three ----------------------------------------
    sm.framesPerSlice = 250; sm.numVolumes = 7; sm.numSlices = 2;
    sm.reset_log();
    c = r.getAcqCounts();
    assert(isstruct(c) && c.framesPerSlice == 250 && c.numVolumes == 7 && c.numSlices == 2, ...
        'getAcqCounts must read all three counts');
    assert(isempty(sm.writes), 'reading the counts must not write anything');

    % --- 2. a property this ScanImage version lacks is ABSENT, not an error ------
    sm2 = FakeStackManager(); sm2.absent = {'numSlices'};
    r.hSI = struct('hStackManager', sm2);
    c2 = r.getAcqCounts();
    assert(isstruct(c2), 'a missing property must not make the whole snapshot fail');
    assert(~isfield(c2, 'numSlices'), 'an absent property must be omitted, not []');
    assert(isfield(c2, 'framesPerSlice') && isfield(c2, 'numVolumes'), ...
        'the properties that DO exist must still be captured');

    % no hStackManager at all -> [] rather than an error
    r.hSI = struct();
    assert(isempty(r.getAcqCounts()), 'no hStackManager must give []');

    % --- 3. NEUTRALITY: nothing drifted -> nothing written -----------------------
    % The property the whole guard rests on. These counts are coupled, so a redundant
    % write to one re-derives the others -- restoring an unchanged value is not free.
    sm3 = FakeStackManager();
    r.hSI = struct('hStackManager', sm3);
    c3 = r.getAcqCounts();
    sm3.reset_log();
    r.restoreAcqCounts(c3, 'prime');
    assert(isempty(sm3.writes), ...
        'a prime that changed nothing must write nothing, got %s', ...
        strjoin(sm3.written(), ','));

    % --- 4. only the drifted field is written ------------------------------------
    sm3.reset_log();
    sm3.numVolumes = 99;              % something moved just this one
    sm3.reset_log();
    r.restoreAcqCounts(c3, 'prime');
    assert(isequal(sm3.written(), {'numVolumes'}), ...
        'only the drifted count should be rewritten, got %s', strjoin(sm3.written(), ','));
    assert(sm3.numVolumes == c3.numVolumes, 'the value must be put back');

    % --- 5. THE REAL BUG: enable re-derives the counts, guard puts them back ------
    sm4 = FakeStackManager();
    sm4.couple = true;                                  % as ScanImage behaves
    r.hSI = struct('hStackManager', sm4);
    sm4.framesPerSlice = 300; sm4.numVolumes = 11; sm4.numSlices = 1;
    want = r.getAcqCounts();                            % what the operator set

    r.restoreStackEnable(true);                         % the prime's enable write
    assert(sm4.numVolumes ~= want.numVolumes, ...
        'the fake must reproduce the re-derivation, else this test proves nothing');

    r.restoreAcqCounts(want, 'prime');
    got = r.getAcqCounts();
    assert(isequaln(got, want), ...
        'the operator''s counts must survive the enable write: wanted %s, got %s', ...
        r.fmt_counts(want), r.fmt_counts(got));

    % --- 6. ORDER: enable must be written BEFORE the counts ----------------------
    % Reversed, the enable write would re-derive over the freshly restored counts.
    order = sm4.written();
    i_enable = find(strcmp(order, 'enable'), 1, 'last');
    i_counts = find(ismember(order, {'numVolumes', 'numSlices', 'framesPerSlice'}), 1, 'last');
    assert(~isempty(i_enable) && ~isempty(i_counts) && i_enable < i_counts, ...
        'enable must be written before the counts (order was: %s)', strjoin(order, ','));

    % --- 7. noteAcqDrift names the FIRST step only -------------------------------
    r.acq_drift = '';
    sm5 = FakeStackManager();
    r.hSI = struct('hStackManager', sm5);
    base = r.getAcqCounts();
    r.noteAcqDrift(base, 'abort');
    assert(isempty(r.acq_drift), 'no drift yet -> nothing recorded');
    sm5.framesPerSlice = 1;                       % something moved it
    r.noteAcqDrift(base, 'updateView');
    assert(strcmp(r.acq_drift, 'updateView'), 'must record the step that moved it');
    sm5.framesPerSlice = 2;                       % moves again later
    r.noteAcqDrift(base, 'restoreStackEnable');
    assert(strcmp(r.acq_drift, 'updateView'), ...
        'must keep the FIRST step; a later one would bury the real cause');

    % --- 8. checkAcqCounts warns and does NOT write ------------------------------
    sm6 = FakeStackManager();
    r.hSI = struct('hStackManager', sm6);
    c6 = r.getAcqCounts();
    sm6.framesPerSlice = 4242;
    sm6.reset_log();
    w = warning('off', 'SIReceiver:acqCountDrift');
    restore = onCleanup(@() warning(w));
    lastwarn('');
    r.checkAcqCounts(c6, 'startLoop');
    [~, wid] = lastwarn();
    assert(strcmp(wid, 'SIReceiver:acqCountDrift'), ...
        'drift after arming must warn, got "%s"', wid);
    assert(isempty(sm6.writes), ...
        'checkAcqCounts must NOT write -- pushing geometry into an armed acquisition');

    % ...and stays silent when nothing drifted
    lastwarn('');
    c6b = r.getAcqCounts();
    r.checkAcqCounts(c6b, 'startLoop');
    [~, wid2] = lastwarn();
    assert(isempty(wid2), 'no drift must produce no warning, got "%s"', wid2);

    % --- 9. an empty snapshot is a no-op everywhere ------------------------------
    r.hSI = struct();
    r.restoreAcqCounts([], 'prime');   % must not error
    r.checkAcqCounts([], 'startLoop');
    r.noteAcqDrift([], 'abort');
    assert(strcmp(r.fmt_counts([]), 'counts unavailable'));

    fprintf(['PASS test_si_acq_counts (reads all three, absent property omitted, ' ...
             'neutral when unchanged, restores only drift, survives the enable ' ...
             're-derivation, enable-before-counts order, first-step drift, ' ...
             'check warns without writing).\n']);
end

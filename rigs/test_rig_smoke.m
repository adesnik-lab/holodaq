function test_rig_smoke()
%TEST_RIG_SMOKE Off-rig sanity checks for the rig configuration system.
%   Run from the repo root (no hardware needed):
%       matlab -batch "addpath(genpath(pwd)); test_rig_smoke"
%   Errors on the first failure; prints PASS on success.

    % holodaq repo on the path, skipping dot-dirs (.git, .claude worktrees hold
    % stale class copies that would shadow the real ones)
    p = strsplit(genpath(fileparts(fileparts(mfilename('fullpath')))), pathsep);
    p = p(~cellfun(@isempty, p) & ~contains(p, [filesep '.']));
    addpath(strjoin(p, pathsep));

    % stim_data_root() consults a machine-level pref ('Scope2kProfile' /
    % 'save_root') that the ExperimentLauncher sets on a real rig PC, and that
    % pref outranks rig.paths.data_root. Park it empty for the duration of the
    % test so the save-root checks describe the code rather than this machine
    % (and so Saver writes under tempdir, not under the rig's real save root).
    % The guard is an onCleanup, so the pref is handed back as it was found even
    % when an assert below throws and aborts the file.
    pref_guard = save_root_pref_guard();   %#ok<NASGU> - restores on error too
    set_save_root_pref('');

    % ---- no rig loaded: fallbacks work, no-fallback errors -------------------
    rig_store('clear');
    assert(strcmp(rig_get('network.holochat_server', 'fb'), 'fb'), 'fallback with no rig');
    err = '';
    try
        rig_get('daq.device');
    catch ME
        err = ME.identifier;
    end
    assert(strcmp(err, 'rig_get:missing'), 'rig_get without fallback must error when no rig is loaded');

    % ---- shipped rig files load and validate ---------------------------------
    rig = load_rig('Example');
    assert(strcmp(rig.name, 'Example'), 'ExampleRig loads by short name');

    rig = load_rig('Scope2K');
    assert(rig.daq.rate == 20000, 'Scope2K rate');
    assert(strcmp(rig_get('network.remote_api'), 'http://127.0.0.1:8765/api'), ...
        'remote_api derived from remote_port');
    assert(rig_has(rig, 'patch') && rig_has(rig, 'fpc_900'), 'module presence');
    assert(~rig_has(rig, 'no_such_module'), 'absent module');
    assert(rig_has(rig, 'serial.ell14') && ~rig_has(rig, 'serial.nope'), 'dotted rig_has');
    assert(strcmp(rig_get('daq.device', 'DevX'), ''), 'explicitly-empty field wins over fallback');

    % cached: a plain load_rig() must return the same rig without re-resolving
    rig2 = load_rig();
    assert(strcmp(rig2.name, 'Scope2K'), 'cache reuse');

    % ---- validation failures --------------------------------------------------
    expect_error(bad_rig('modules', struct('a', struct('output', 'ao0'), ...
                                           'b', struct('input', 'ao0'))), ...
        'load_rig:duplicateChannel');
    expect_error(bad_rig('modules', struct('a', struct('output', 'bogus7'))), ...
        'load_rig:badChannel');
    expect_error(bad_rig('modules', struct('a', struct('serial', 'nope'))), ...
        'load_rig:badSerialRef');
    norate = bad_rig('modules', struct('a', struct('output', 'ao0')));
    norate.daq = struct();   % channels declared but no rate
    expect_error(norate, 'load_rig:invalid');

    % ---- class internals read the loaded rig -----------------------------------
    trig = base_rig();
    trig.daq.device = 'Dev7';
    trig.daq.rate = 1000;
    trig.paths.data_root = fullfile(tempdir, 'holodaq_smoke');
    trig.modules.patch = struct('output', 'ao0', 'input', 'ai7');
    load_rig(trig);

    fd = fakedaq();
    assert(strcmp(fd.dev, 'Dev7'), 'fakedaq picks up rig.daq.device');
    fd.Rate = trig.daq.rate;

    out = Output(DAQOutput(fd, trig.modules.patch.output), 'patch output');
    in  = Input(DAQInput(fd, trig.modules.patch.input), 'patch input');
    assert(strcmp(out.interface.dev, 'Dev7'), 'DAQInterface picks up rig.daq.device');
    assert(strcmp(out.interface.type, 'voltage') && strcmp(in.interface.type, 'voltage'), ...
        'channel type derivation');

    % with the profile pref parked empty (top of this file), the rig wins
    sv = Saver('smokemouse', 1, 'smoke', 'overwrite');
    assert(strcmp(sv.base_path, stim_data_root()), 'Saver takes base_path from stim_data_root');
    assert(strcmp(sv.base_path, trig.paths.data_root), 'Saver picks up rig.paths.data_root');

    rig_store('clear');
    fd2 = fakedaq();
    assert(strcmp(fd2.dev, 'Dev1'), 'fakedaq default with no rig');

    % ---- save-root resolution order (pref > rig > default) --------------------
    test_stim_data_root();

    disp('PASS: rig smoke test');
end

function test_stim_data_root()
%TEST_STIM_DATA_ROOT Directed check of stim_data_root's three-way resolution.
%   The caller owns the pref guard (see save_root_pref_guard), so this is free
%   to set and remove the pref. Leaves the rig store cleared.

    pref_root = fullfile(tempdir, 'holodaq_smoke_pref');
    rig = base_rig();
    rig.paths.data_root = fullfile(tempdir, 'holodaq_smoke_rig');
    load_rig(rig);

    set_save_root_pref(pref_root);
    assert(strcmp(stim_data_root(), pref_root), ...
        'a non-empty profile pref must outrank rig.paths.data_root');

    set_save_root_pref('');
    assert(strcmp(stim_data_root(), rig.paths.data_root), ...
        'an empty profile pref must fall through to rig.paths.data_root');

    clear_save_root_pref();
    assert(strcmp(stim_data_root(), rig.paths.data_root), ...
        'an absent profile pref must fall through to rig.paths.data_root');

    % Neither pref nor rig: the documented hardcoded default. Silence just the
    % id stim_data_root warns with on this branch (and put the state back) so
    % the smoke test's own output stays clean.
    rig_store('clear');
    ws = warning('off', 'stim_data_root:default');
    warn_guard = onCleanup(@() warning(ws));   %#ok<NASGU> - restores on error too
    assert(strcmp(stim_data_root(), 'K://KKS//stim-data'), ...
        'no pref and no rig must give the documented default root');
end

% ---- machine-level save-root pref -------------------------------------------
% stim_data_root reads getpref('Scope2kProfile', 'save_root'). These let the
% test drive that pref and hand it back exactly as found: absent stays absent,
% set stays set with its original value.

function guard = save_root_pref_guard()
    if ispref('Scope2kProfile', 'save_root')
        saved = getpref('Scope2kProfile', 'save_root');
        guard = onCleanup(@() setpref('Scope2kProfile', 'save_root', saved));
    else
        guard = onCleanup(@clear_save_root_pref);
    end
end

function set_save_root_pref(value)
    setpref('Scope2kProfile', 'save_root', value);
end

function clear_save_root_pref()
    if ispref('Scope2kProfile', 'save_root')
        rmpref('Scope2kProfile', 'save_root');
    end
end

function rig = base_rig()
    rig = struct('name', 'SmokeTest');
    rig.daq = struct('vendor', 'ni', 'device', '', 'rate', 20000);
end

function rig = bad_rig(field, value)
    rig = base_rig();
    rig.(field) = value;
end

function expect_error(rig, id)
    err = '';
    try
        load_rig(rig);
    catch ME
        err = ME.identifier;
    end
    rig_store('clear');
    assert(strcmp(err, id), 'expected error %s, got ''%s''', id, err);
end

function test_si_user_functions()
%TEST_SI_USER_FUNCTIONS  Priming must not touch the operator's user functions.
%
%   >> addpath(genpath(<holodaq>)); test_si_user_functions
%
%   The bug: set_user_function called disable_all_user_functions, which set
%   Enable = 0 on EVERY entry and then enabled only the one named by si_callback.
%   Every si_callback in every manifest is '', so the first prime of a session
%   silently killed arm_reset_callback and online_analysis_callback for the rest of
%   the session. Per the operator, user functions are managed by hand, so the prime
%   must leave them alone.

    r = SIReceiver('D:');

    % --- 1. si_callback '' must leave EVERYTHING exactly as the operator set it ---
    ufn = FakeUserFunctions({'arm_reset_callback', 'online_analysis_callback', 'other'}, ...
                            [true, true, false]);
    r.hSI = struct('hUserFunctions', ufn);
    r.config = struct('si_callback', '');
    r.set_user_function();
    assert(ufn.is_enabled('arm_reset_callback'), ...
        'arm_reset_callback was disabled by a prime -- this is the bug');
    assert(ufn.is_enabled('online_analysis_callback'), ...
        'online_analysis_callback was disabled by a prime -- this is the bug');
    assert(~ufn.is_enabled('other'), 'a disabled function must stay disabled');

    % --- 2. a missing si_callback field is the same no-op -----------------------
    r.config = struct();
    r.set_user_function();
    assert(ufn.is_enabled('arm_reset_callback') && ufn.is_enabled('online_analysis_callback'));

    % --- 3. a named si_callback is enabled ADDITIVELY, disabling nothing ---------
    r.config = struct('si_callback', 'other');
    r.set_user_function();
    assert(ufn.is_enabled('other'), 'the named callback must be enabled');
    assert(ufn.is_enabled('arm_reset_callback') && ufn.is_enabled('online_analysis_callback'), ...
        'enabling one callback must not disable the others');

    % --- 4. an unknown si_callback warns and changes nothing --------------------
    before = [ufn.userFunctionsCfg.Enable];
    w = warning('off', 'all');
    restore = onCleanup(@() warning(w));
    lastwarn('');
    r.config = struct('si_callback', 'no_such_callback');
    r.set_user_function();
    [msg] = lastwarn();
    assert(contains(msg, 'no_such_callback'), 'an unknown callback must warn, got "%s"', msg);
    assert(isequal([ufn.userFunctionsCfg.Enable], before), ...
        'a bad callback name must not change any Enable flag');

    % --- 5. enabled_user_functions reports what will actually fire ---------------
    names = r.enabled_user_functions();
    assert(all(ismember({'arm_reset_callback', 'online_analysis_callback', 'other'}, names)), ...
        'enabled_user_functions must list every enabled callback, got %s', ...
        strjoin(names, ','));

    ufn2 = FakeUserFunctions({'a', 'b'}, [false, false]);
    r.hSI = struct('hUserFunctions', ufn2);
    [names2, ok2] = r.enabled_user_functions();
    assert(isempty(names2) && ok2, 'none enabled -> empty list but a SUCCESSFUL read');

    % missing hUserFunctions entirely -> empty AND ok=false. "unreadable" must be
    % distinguishable from "none enabled": reporting the former as NONE would assert
    % something untrue about which callbacks are about to fire.
    r.hSI = struct();
    [names3, ok3] = r.enabled_user_functions();
    assert(isempty(names3) && ~ok3, 'an unreadable list must report ok=false, not NONE');

    % --- 6. the manual utility still works when called deliberately --------------
    r.hSI = struct('hUserFunctions', ufn);
    r.disable_all_user_functions();
    assert(~ufn.is_enabled('arm_reset_callback') && ~ufn.is_enabled('other'), ...
        'disable_all_user_functions must still turn everything off when called by hand');

    fprintf(['PASS test_si_user_functions (prime leaves the operator''s checkboxes ' ...
             'alone, named callback is additive, bad name warns, reporting works).\n']);
end

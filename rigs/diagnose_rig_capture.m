function diagnose_rig_capture(name)
%DIAGNOSE_RIG_CAPTURE Report why a rig file's one-time legacy capture did not fire.
%   DIAGNOSE_RIG_CAPTURE() checks Scope2KRig; DIAGNOSE_RIG_CAPTURE('Foo') checks
%   FooRig. Read-only: it reads the legacy sources but never rewrites anything, so
%   it is safe to run repeatedly.
%
%   Checks, in the order they actually gate the capture:
%     1. which file the MATLAB path resolves the rig to (and whether it is shadowed)
%     2. whether that file even has the <captured:...> anchors
%     3. whether its literals are still empty (i.e. whether capture SHOULD fire)
%     4. whether the file is writable
%     5. whether the legacy source drive and files are reachable
%     6. what the legacy sources actually return
%
%   See also: Scope2KRig, load_rig

    if nargin < 1 || isempty(name)
        name = 'Scope2K';
    end
    fn_name = char(name);
    if ~endsWith(fn_name, 'Rig')
        fn_name = [fn_name 'Rig'];
    end

    fprintf('\n=== diagnose_rig_capture: %s ===\n\n', fn_name);
    fields = {'calibration_900', 'calibration_1100', 'holo_request'};

    % --- 1. which file runs -------------------------------------------------
    hits = which(fn_name, '-all');
    if ischar(hits), hits = {hits}; end
    hits = hits(~cellfun(@isempty, hits));
    if isempty(hits)
        fprintf('1. FAIL  %s is not on the MATLAB path at all.\n', fn_name);
        fprintf('\nNothing else can be checked. Add its rigs/ folder to the path.\n');
        return
    end
    file = hits{1};
    fprintf('1. runs  %s\n', file);
    if numel(hits) > 1
        fprintf('   WARN  %d copies on the path -- the first one above wins:\n', numel(hits));
        for i = 2:numel(hits)
            fprintf('         shadowed: %s\n', hits{i});
        end
    end

    % --- 2. anchors present -------------------------------------------------
    try
        txt = fileread(file);
    catch err
        fprintf('2. FAIL  cannot read that file: %s\n', err.message);
        return
    end
    n_anchor = numel(fields);
    for i = 1:numel(fields)
        n = numel(strfind(txt, sprintf('<captured:%s>', fields{i})));
        if n ~= 1
            fprintf('2. FAIL  found %d <captured:%s> anchors, expected 1.\n', n, fields{i});
            n_anchor = n_anchor - 1;
        end
    end
    if n_anchor < numel(fields)
        fprintf(['   That file is an OLD copy without the capture block, or its ' ...
                 'anchors were edited.\n   This is the usual cause: git pulled one ' ...
                 'checkout while MATLAB runs another.\n']);
        return
    end
    fprintf('2. ok    all three <captured:...> anchors present\n');

    % --- 3. should capture fire? -------------------------------------------
    still_empty = {};
    for i = 1:numel(fields)
        tok = regexp(txt, sprintf('captured_%s\\s*=\\s*(.*?);\\s*%%\\s*<captured:%s>', ...
                                  fields{i}, fields{i}), 'tokens', 'once');
        if isempty(tok)
            fprintf('3. FAIL  could not parse the captured_%s literal.\n', fields{i});
            return
        end
        val = strtrim(tok{1});
        if strcmp(val, '''''')
            still_empty{end+1} = fields{i}; %#ok<AGROW>
            fprintf('3. empty captured_%-16s = ''''  (capture WILL fire)\n', fields{i});
        else
            fprintf('3. set   captured_%-16s = %s\n', fields{i}, val);
        end
    end
    if isempty(still_empty)
        fprintf(['\nAll three are already filled in, so the capture block is done ' ...
                 'and will never\nfire again. Nothing is wrong. If the values are ' ...
                 'stale, blank one out to re-capture.\n']);
        return
    end

    % --- 4. writable? -------------------------------------------------------
    fid = fopen(file, 'a');
    if fid < 0
        fprintf(['4. FAIL  cannot open the file for writing. The capture would read ' ...
                 'the values but\n         fail to persist them (you would see a ' ...
                 'Scope2KRig:captureWrite warning).\n']);
    else
        fclose(fid);
        fprintf('4. ok    file is writable\n');
    end

    % --- 5. legacy sources reachable ---------------------------------------
    if ~isfolder('K:\')
        fprintf(['5. FAIL  K:\\ is not visible to THIS MATLAB, so there is nothing to ' ...
                 'capture from.\n         (Mapped drives are per-user/per-session on ' ...
                 'Windows -- a drive you can see\n         in Explorer is not always ' ...
                 'visible to a process started differently.)\n']);
        fprintf('\nVerdict: capture cannot run here. Run it where K:\\ resolves.\n');
        return
    end
    fprintf('5. ok    K:\\ is visible\n');
    addpath('K:\');
    have_pc = exist('power_calibrations', 'file') == 2;
    have_fs = exist('FrankenScopeRigFile', 'file') == 2;
    fprintf('   %s power_calibrations    %s\n', tick(have_pc), loc_of('power_calibrations', have_pc));
    fprintf('   %s FrankenScopeRigFile   %s\n', tick(have_fs), loc_of('FrankenScopeRigFile', have_fs));

    % --- 6. what do they actually return? ----------------------------------
    fprintf('\n6. what the legacy sources return:\n');
    if have_pc
        power_calibration = struct('calibration_900', '', 'calibration_1100', '');
        try
            power_calibrations;
            show('calibration_900',  power_calibration.calibration_900);
            show('calibration_1100', power_calibration.calibration_1100);
        catch err
            fprintf('   FAIL  power_calibrations errored: %s\n', err.message);
        end
    end
    if have_fs
        try
            l = FrankenScopeRigFile();
            if isfield(l, 'HoloRequest')
                show('holo_request', l.HoloRequest);
            else
                fprintf('   FAIL  no .HoloRequest field. Fields: %s\n', ...
                    strjoin(fieldnames(l)', ', '));
            end
        catch err
            fprintf('   FAIL  FrankenScopeRigFile errored: %s\n', err.message);
        end
    end

    fprintf(['\nVerdict: everything needed is present, so a fresh ' ...
             '"rig_store(''clear''); load_rig(''%s'')"\nshould capture %s ' ...
             'and rewrite\n  %s\n'], name, strjoin(still_empty, ', '), file);
end


function s = tick(b)
    if b, s = 'ok  '; else, s = 'FAIL'; end
end

function s = loc_of(fname, have)
    if have, s = which(fname); else, s = '(not found on path)'; end
end

function show(label, v)
    if isempty(v)
        fprintf('   FAIL  %-16s is EMPTY -- nothing to capture\n', label);
    else
        fprintf('   ok    %-16s = %s\n', label, char(v));
    end
end

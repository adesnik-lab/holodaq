function rig = Scope2KRig()
%SCOPE2KRIG Rig definition for Scope2K (formerly the FrankenScope).
%   Loaded via load_rig (see rigs/README.md). To adapt holodaq to another
%   microscope, copy rigs/ExampleRig.m — every field is documented there.

rig.name = 'Scope2K';

% ---- values captured from the legacy K:\ rig files -------------------------
% The power->angle LUT paths and the holoRequest folder used to be read at load
% time by running K:\power_calibrations and K:\FrankenScopeRigFile. That made
% this rig file depend on the data drive being mounted: loaded from a machine
% without K:\, the calibration paths came out EMPTY. Tolerable while only this
% machine read them (Experiment.check_rig warns, and the shutter still opens);
% actively unsafe once publish_rig_config ships them to the satellites as
% authoritative config.
%
% So they are plain literals now. The block at the end of this file fills them
% in ONCE, automatically, the first time the file is loaded somewhere that can
% still reach the legacy files, and rewrites the three lines below in place.
% Review the diff and commit it -- after that this rig file needs nothing but
% itself, and the capture block at the bottom is dead code you can delete.
%
% Do not reformat the three lines below or move their <captured:...> tags: the
% rewrite locates them by tag and refuses to touch the file if a tag is missing
% or duplicated.
captured_calibration_900  = '';   % <captured:calibration_900>
captured_calibration_1100 = '';   % <captured:calibration_1100>
captured_holo_request     = '';   % <captured:holo_request>

% ---- paths ---------------------------------------------------------------
% MATLAB paths default_setup adds (data drive + sibling code checkouts).
% MACHINE-SCOPED, not rig-scoped: this is the DAQ's own addpath list, so
% publish_rig_config must NOT ship it to the satellites.
rig.paths.matlab_paths = {'K:\', genpath('C:\Users\holos\Documents\_code')};
rig.paths.data_root    = 'K://KKS//stim-data';   % Saver output root
rig.paths.si_root      = 'D:';                   % ScanImage tiff root (SI computer)
rig.paths.holo_request = captured_holo_request;  % holoRequest.mat folder

% ---- DAQ -------------------------------------------------------------------
rig.daq.vendor = 'ni';
rig.daq.device = '';      % '' = auto-detect (first daqlist device)
rig.daq.rate   = 20000;   % samples/s

% ---- serial devices ----------------------------------------------------------
rig.serial.ell14 = struct('port', 'COM4', 'baud', 9600, ...
    'byte_order', 'big-endian', 'parity', 'none', ...
    'stop_bits', 1, 'data_bits', 8, 'terminator', 'CR/LF');   % HWP rotators
rig.serial.wheel = struct('port', 'COM3', 'baud', 115200, ...
    'terminator', 'CR/LF');                                   % Arduino running wheel

% ---- modules -----------------------------------------------------------------
% A module listed here exists on this rig; omit the field entirely on rigs
% that lack the hardware (scripts skip construction via rig_has).
rig.modules.si         = struct('trigger', 'port0/line0', 'frame', 'ai0');
% PsychToolbox computer trigger. port0/line17 is what Experiment.setup and every
% live non-voltage-imaging runner use. NOTE: the voltage-imaging runners under
% expts/Andrea/voltage-imaging/ instead use port0/line7 for the PTB trigger, and
% additionally bind port0/line2 and port0/line3 as PTB *inputs* -- the lines this
% file assigns to the SLM triggers below. Those runners build the rig inline and
% keep their own literals, so they are unaffected by this entry; resolve on-rig
% whether line7 is a second physical PTB line before migrating them (load_rig's
% duplicate-channel check cannot help, since only one value ever lands here).
rig.modules.ptb        = struct('trigger', 'port0/line17');
rig.modules.holo       = struct();   % HoloComputer: holochat only, no DAQ wiring
rig.modules.fpc_900    = struct('shutter', 'port0/line5', 'serial', 'ell14', ...
    'ell14_channel', 1, 'calibration', captured_calibration_900, 'khz', 250);
rig.modules.fpc_1100   = struct('shutter', 'port0/line4', 'serial', 'ell14', ...
    'ell14_channel', 2, 'calibration', captured_calibration_1100, 'khz', 250);
rig.modules.slm_900    = struct('trigger', 'port0/line2', 'flip', 'ai1');
rig.modules.slm_1100   = struct('trigger', 'port0/line3', 'flip', 'ai2');
rig.modules.patch      = struct('output', 'ao0', 'input', 'ai7');
rig.modules.wheel      = struct('serial', 'wheel');
rig.modules.laser_gate = struct('output', 'ao1', 'max_voltage', 3.5);

% ---- opto (photostim) channels ---------------------------------------------
% THE declaration of this rig's opto channel identity: one entry per laser + SLM
% path. Both halves of an entry are load-bearing.
%   name       -> the params.pool field. 'red'/'blue' are exactly what the ~36
%                 existing experiment files already write (pool(ct).red /
%                 pool(ct).blue), so they run unedited and no alias is needed.
%   wavelength -> DERIVES params.holoinfo.hr<nm> and the saved stim_<nm> (see
%                 opto_channels), reproducing hr1100/hr900 and
%                 stim_1100/stim_900 exactly. Never hand-typed, so a rig-file
%                 typo cannot cross one laser's power command with another
%                 wavelength's calibration.
% ORDER IS THE WIRE ORDER: the sequence holoRequests are transferred in and the
% cell position of each firing order. 1100 first reproduces today's transfer
% order (FullExperiment.initialize sends hr1100 then hr900) and the holo
% listener's historical [1100 900] default, so an un-updated listener still
% agrees. Note this is deliberately NOT the module add order in
% Experiment.setup, which adds 900 first -- that order fixes DAQ channel
% registration and is a separate concern.
%
% slm_board/slm_lut are deliberately left unset (== 'auto'). Pinning them here
% is safe ONLY in the same commit that teaches start_holo_listener's
% local_signature to report the real board: opto_signature emits '#<board>'
% once pinned while that function hardcodes '#auto', so the exact-match gate in
% Experiment.confirm_opto_agreement would fail and fall through to the weak
% wavelength-only branch -- silently downgrading the check that exists to stop a
% beam being steered by the wrong phase mask.
rig.opto = [ opto_channel('red',  1100, 'fpc_1100', 'slm_1100'), ...
             opto_channel('blue',  900, 'fpc_900',  'slm_900') ];

% ---- network -------------------------------------------------------------------
rig.network.holochat_server = 'http://136.152.58.120:8000';   % holochat broker
rig.network.remote_port     = 8765;                           % phone-control server (remote/)

% ---- one-time capture from the legacy K:\ files --------------------------------
% Runs only while one of the captured literals at the top is still empty. See the
% note there. Once all three are filled in and committed, this never fires again.
missing = {};
if isempty(captured_calibration_900),  missing{end+1} = 'calibration_900';  end %#ok<*AGROW>
if isempty(captured_calibration_1100), missing{end+1} = 'calibration_1100'; end
if isempty(captured_holo_request),     missing{end+1} = 'holo_request';     end

if ~isempty(missing)
    got = local_capture(missing, mfilename('fullpath'));
    % Apply to THIS session too, so a machine that can reach K:\ behaves
    % identically to before the capture existed.
    if isfield(got, 'calibration_900')
        rig.modules.fpc_900.calibration  = got.calibration_900;
    end
    if isfield(got, 'calibration_1100')
        rig.modules.fpc_1100.calibration = got.calibration_1100;
    end
    if isfield(got, 'holo_request')
        rig.paths.holo_request = got.holo_request;
    end
end
end


function got = local_capture(missing, thisfile)
%LOCAL_CAPTURE Read the legacy K:\ values for MISSING, then persist them inline.
%   Returns a struct with a field per value it managed to read. Every failure is
%   a warning, never an error: a rig that cannot reach K:\ must still load (it
%   did before), just with the values empty and said out loud.
    got = struct();

    if ~isfolder('K:\')
        warning('Scope2KRig:legacyUnavailable', ...
            ['Cannot capture %s: K:\\ is not mounted.\n' ...
             'This rig loads with those values EMPTY, which means power is NOT ' ...
             'clamped (Experiment\nwarns) and publish_rig_config must not ship ' ...
             'them as authoritative. Load this rig\nonce on a machine with K:\\ ' ...
             'mounted to capture them permanently.'], strjoin(missing, ', '));
        return
    end
    addpath('K:\');

    wants = @(f) any(strcmp(f, missing));

    if (wants('calibration_900') || wants('calibration_1100')) ...
            && exist('power_calibrations', 'file')
        % Pre-declared because power_calibrations is a legacy SCRIPT that fills
        % this variable in our workspace rather than returning anything.
        power_calibration = struct('calibration_900', '', 'calibration_1100', '');
        power_calibrations;
        if wants('calibration_900') && ~isempty(power_calibration.calibration_900)
            got.calibration_900 = char(power_calibration.calibration_900);
        end
        if wants('calibration_1100') && ~isempty(power_calibration.calibration_1100)
            got.calibration_1100 = char(power_calibration.calibration_1100);
        end
    end

    if wants('holo_request') && exist('FrankenScopeRigFile', 'file')
        loc = FrankenScopeRigFile();
        if isfield(loc, 'HoloRequest') && ~isempty(loc.HoloRequest)
            got.holo_request = char(loc.HoloRequest);
        end
    end

    fields = fieldnames(got);
    if isempty(fields)
        warning('Scope2KRig:legacyEmpty', ...
            ['K:\\ is mounted but yielded nothing for %s.\n' ...
             'Check that K:\\power_calibrations.m and K:\\FrankenScopeRigFile.m ' ...
             'still exist and\nstill set the fields this reads.'], ...
            strjoin(missing, ', '));
        return
    end

    written = {};
    for i = 1:numel(fields)
        if local_rewrite(thisfile, fields{i}, got.(fields{i}))
            written{end+1} = fields{i}; %#ok<AGROW>
        end
    end

    if ~isempty(written)
        fprintf('Scope2KRig: captured %d legacy value(s) into\n  %s\n', ...
            numel(written), thisfile);
        for i = 1:numel(written)
            fprintf('    %-16s = %s\n', written{i}, got.(written{i}));
        end
        fprintf(['Review the diff and commit it. After that this rig file no ' ...
                 'longer needs K:\\.\n']);
    end
end


function ok = local_rewrite(file, field, value)
%LOCAL_REWRITE Replace the <captured:FIELD>-tagged line in FILE with VALUE.
%   Deliberately plain string surgery rather than regexprep: the values are
%   Windows paths full of backslashes, which a replacement pattern would mangle.
    ok = false;
    tag = sprintf('<captured:%s>', field);

    try
        txt = fileread(file);
    catch err
        warning('Scope2KRig:captureRead', ...
            'Captured %s but could not read\n  %s\nto persist it (%s).', ...
            field, file, err.message);
        return
    end

    lines = regexp(txt, '\r\n|\n|\r', 'split');
    hit   = find(contains(lines, tag));
    if numel(hit) ~= 1
        warning('Scope2KRig:captureAnchor', ...
            ['Captured %s but found %d lines tagged %s in\n  %s\n' ...
             'Expected exactly 1, so NOT rewriting. Set the literal by hand.'], ...
            field, numel(hit), tag, file);
        return
    end

    quoted = local_quote(value);
    lines{hit} = sprintf('captured_%s%s = %s;   %% %s', field, ...
        repmat(' ', 1, max(0, 16 - numel(field))), quoted, tag);

    if contains(txt, sprintf('\r\n'))
        nl = sprintf('\r\n');
    else
        nl = sprintf('\n');
    end

    tmp = [file '.capture-tmp'];
    fid = fopen(tmp, 'w');
    if fid < 0
        warning('Scope2KRig:captureWrite', ...
            ['Captured %s but could not open\n  %s\nfor writing. Is the checkout ' ...
             'read-only? Set the literal by hand.'], field, tmp);
        return
    end
    fprintf(fid, '%s', strjoin(lines, nl));
    fclose(fid);

    % Verify the temp file before letting it replace the original.
    check = fileread(tmp);
    if ~contains(check, tag) || ~contains(check, quoted)
        delete(tmp);
        warning('Scope2KRig:captureVerify', ...
            'Rewrite for %s did not verify; original left untouched.', field);
        return
    end

    [ok, msg] = movefile(tmp, file, 'f');
    if ~ok
        warning('Scope2KRig:captureMove', ...
            'Could not replace\n  %s\n(%s)', file, msg);
        if isfile(tmp), delete(tmp); end
    end
end


function s = local_quote(v)
%LOCAL_QUOTE A MATLAB single-quoted literal for V (backslashes need no escape).
    s = ['''' strrep(char(v), '''', '''''') ''''];
end

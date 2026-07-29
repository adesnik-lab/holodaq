function rig = load_rig(name)
%LOAD_RIG Load, validate, and cache the rig definition for this machine.
%   A "rig file" is a function in rigs/ that returns a struct describing one
%   microscope: DAQ channels, serial ports, modules, network, paths. See
%   rigs/ExampleRig.m for the full schema and rigs/README.md for setup.
%
%   rig = LOAD_RIG()            resolve the rig automatically (see below)
%   rig = LOAD_RIG('Scope2K')   load a specific rig ('Scope2K' or 'Scope2KRig')
%   rig = LOAD_RIG(@Scope2KRig) load from a function handle
%   rig = LOAD_RIG(s)           validate + cache a pre-built rig struct
%
%   Automatic resolution order (no argument):
%     1. the rig already loaded this session (cached)
%     2. the HOLODAQ_RIG environment variable (rig name)
%     3. a rig_config.m on the MATLAB path returning the rig name
%        (per-machine, gitignored — copy rigs/rig_config.m.example)
%     4. if rigs/ holds exactly one <Name>Rig.m besides ExampleRig, use it
%     5. otherwise error, listing the available rig files.
%
%   The loaded rig is cached so class internals can read it anywhere via
%   rig_get without threading the struct through every constructor.
%
%   See also RIG_GET, RIG_HAS, OPEN_SERIAL.

    if nargin < 1
        name = '';
    end

    % Reuse the cached rig unless a specific one is requested.
    if isempty(name)
        rig = rig_store('get');
        if ~isempty(rig)
            return
        end
    end

    if isstruct(name)
        rig = name;
        source = 'struct argument';
    else
        [fn, source] = resolve_rig_function(name);
        rig = fn();
    end

    rig = validate_rig(rig);
    rig_store('set', rig);
    fprintf('load_rig: using rig ''%s'' (%s).\n', rig.name, source);
end

% -------------------------------------------------------------------------
function [fn, source] = resolve_rig_function(name)
    if isa(name, 'function_handle')
        fn = name;
        source = 'function handle';
        return
    end

    name = char(name);
    if ~isempty(name)
        fn = rig_function_by_name(name);
        source = sprintf('requested ''%s''', name);
        return
    end

    env = getenv('HOLODAQ_RIG');
    if ~isempty(env)
        fn = rig_function_by_name(env);
        source = 'HOLODAQ_RIG environment variable';
        return
    end

    if exist('rig_config', 'file') == 2
        fn = rig_function_by_name(rig_config());
        source = 'rig_config.m';
        return
    end

    % Last resort: a lone rig file in this folder is unambiguous.
    candidates = list_rig_files();
    if numel(candidates) == 1
        fn = str2func(candidates{1});
        source = sprintf('only rig file in %s', rigs_dir());
        return
    end

    error('load_rig:noRig', ...
        ['Could not determine which rig to load.\n' ...
         'Available rig files in %s: %s\n' ...
         'Select one by (a) calling load_rig(''<Name>''), (b) setting the\n' ...
         'HOLODAQ_RIG environment variable, or (c) copying\n' ...
         'rigs/rig_config.m.example to rig_config.m (gitignored) on your path.\n' ...
         'To define a new rig, copy rigs/ExampleRig.m.'], ...
        rigs_dir(), strjoin(candidates, ', '));
end

function fn = rig_function_by_name(name)
    name = regexprep(char(name), '\.m$', '');
    for candidate = {name, [name 'Rig']}
        if exist(candidate{1}, 'file') == 2
            fn = str2func(candidate{1});
            return
        end
    end
    error('load_rig:notFound', ...
        'No rig file ''%s'' (or ''%sRig'') found on the MATLAB path. Available: %s', ...
        name, name, strjoin(list_rig_files(), ', '));
end

function d = rigs_dir()
    d = fileparts(mfilename('fullpath'));
end

function names = list_rig_files()
    files = dir(fullfile(rigs_dir(), '*Rig.m'));   % case-insensitive on mac/win
    names = regexprep({files.name}, '\.m$', '');
    names = names(~cellfun(@isempty, regexp(names, 'Rig$', 'once')));   % drop load_rig etc.
    names = setdiff(names, {'ExampleRig'});
end

% -------------------------------------------------------------------------
function rig = validate_rig(rig)
    assert(isstruct(rig) && isscalar(rig), 'load_rig:invalid', ...
        'A rig definition must be a scalar struct.');
    assert(isfield(rig, 'name') && ~isempty(rig.name), 'load_rig:invalid', ...
        'Rig file must set rig.name.');

    % ---- defaults ----
    rig = setdefault(rig, 'daq', struct());
    rig.daq = setdefault(rig.daq, 'vendor', 'ni');
    rig.daq = setdefault(rig.daq, 'device', '');   % '' = auto-detect
    rig.daq = setdefault(rig.daq, 'rate', []);
    rig = setdefault(rig, 'serial', struct());
    rig = setdefault(rig, 'modules', struct());
    rig = setdefault(rig, 'network', struct());
    rig.network = setdefault(rig.network, 'remote_port', 8765);
    rig.network = setdefault(rig.network, 'remote_api', '');
    if isempty(rig.network.remote_api)
        rig.network.remote_api = sprintf('http://127.0.0.1:%d/api', rig.network.remote_port);
    end
    rig = setdefault(rig, 'paths', struct());
    rig.paths = setdefault(rig.paths, 'matlab_paths', {});

    % ---- modules: channel formats, duplicates, serial refs, calibrations ----
    % Field names that hold physical DAQ terminals. Patterns must stay in sync
    % with DAQInterface.derive_type (digital / voltage / counter).
    channel_fields  = {'trigger', 'frame', 'shutter', 'flip', 'output', 'input', 'counter'};
    channel_pattern = '^(port[0-9]+/line[0-9]+|a[io][0-9]+|ctr[0-9]+)$';

    seen_channels = cell(0, 2);   % {physical_channel, 'module.field'} rows
    uses_daq = false;
    for mod_name = fieldnames(rig.modules)'
        m = rig.modules.(mod_name{1});
        assert(isstruct(m), 'load_rig:invalid', ...
            'rig.modules.%s must be a struct (use struct() for a module with no wiring).', mod_name{1});

        for f = channel_fields
            if ~isfield(m, f{1})
                continue
            end
            uses_daq = true;
            ch = strtrim(char(m.(f{1})));
            where = sprintf('%s.%s', mod_name{1}, f{1});
            assert(~isempty(regexp(ch, channel_pattern, 'once')), 'load_rig:badChannel', ...
                ['rig.modules.%s = ''%s'' is not a recognized DAQ channel ' ...
                 '(expected port<n>/line<n>, ai<n>, ao<n>, or ctr<n>).'], where, ch);
            dup = strcmp(ch, seen_channels(:, 1));
            assert(~any(dup), 'load_rig:duplicateChannel', ...
                'Physical channel ''%s'' is assigned to both %s and %s.', ...
                ch, strjoin(seen_channels(dup, 2), ', '), where);
            seen_channels(end+1, :) = {ch, where}; %#ok<AGROW>
        end

        if isfield(m, 'serial')
            assert(isfield(rig.serial, m.serial), 'load_rig:badSerialRef', ...
                'rig.modules.%s.serial = ''%s'' but rig.serial has no ''%s'' entry.', ...
                mod_name{1}, m.serial, m.serial);
        end

        if isfield(m, 'calibration') && ~isempty(m.calibration) && ~exist(m.calibration, 'file')
            warning('load_rig:calibration', ...
                'Calibration file for module ''%s'' not found: %s (fine if editing off-rig).', ...
                mod_name{1}, m.calibration);
        end
    end

    if uses_daq
        assert(isnumeric(rig.daq.rate) && isscalar(rig.daq.rate) && rig.daq.rate > 0, ...
            'load_rig:invalid', 'rig.daq.rate must be a positive scalar (samples/s) when DAQ channels are declared.');
        assert(~isempty(rig.daq.vendor), 'load_rig:invalid', ...
            'rig.daq.vendor must be set (e.g. ''ni'') when DAQ channels are declared.');
    end
end

function s = setdefault(s, field, value)
    if ~isfield(s, field)
        s.(field) = value;
    end
end

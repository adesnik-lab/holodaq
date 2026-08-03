function chans = opto_channels(rig)
%OPTO_CHANNELS Resolve and validate a rig's optogenetic channel table.
%   chans = OPTO_CHANNELS(rig) returns the rig's opto channels as a struct array
%   in DECLARATION ORDER -- the order holoRequests are transferred to the
%   holography computer -- with the derived field names filled in:
%
%     .name        pool field an experiment writes:  params.pool(i).<name>
%     .wavelength  nm
%     .fpc         rig.modules entry: power control + shutter
%     .slm         rig.modules entry: hologram trigger
%     .slm_board   SLM board index, or [] to let the holo computer derive it
%     .slm_lut     SLM lookup table, or '' for the holo computer's default
%     .pool_field  == .name
%     .holo_field  sprintf('hr%d', wavelength)      e.g. 'hr900'
%     .save_field  sprintf('stim_%d', wavelength)   e.g. 'stim_900'
%
%   The three derived names are computed here, never stored in the rig file, so a
%   channel cannot be wired to one wavelength's hardware and another's data.
%
%   A rig with no rig.opto field returns an empty table rather than erroring: a
%   vis-only rig (no lasers at all) is a legitimate configuration.
%
%   load_rig calls this so a malformed table is refused at load time, before any
%   hardware is opened.
%
%   Cross-channel rules enforced here (single-channel rules live in opto_channel):
%     * every .fpc / .slm names an existing rig.modules entry   (noModule)
%     * channel names are unique                                (duplicateName)
%     * no two channels share an fpc or an slm module           (moduleReuse)
%     * no two channels share a half-wave-plate address         (sharedRotator)
%     * two channels at one wavelength must pin distinct boards (sharedWavelengthNoBoard)
%     * declared boards, where given, are distinct              (sharedBoard)
%
%   See also: opto_channel, opto_signature, load_rig

    if nargin < 1 || isempty(rig)
        rig = load_rig();
    end

    chans = local_empty();

    if ~isstruct(rig) || ~isfield(rig, 'opto') || isempty(rig.opto)
        return
    end

    raw = rig.opto;
    if iscell(raw)
        raw = local_cell_to_struct(raw);
    end
    assert(isstruct(raw), 'opto_channels:badTable', ...
        ['rig.opto must be a struct array built with opto_channel(), got %s.\n' ...
         'e.g. rig.opto = opto_channel(''opto'', 1030, ''fpc_1030'', ''slm_1030'');'], ...
        class(rig.opto));

    % Accept a row or a column: rig files write [a, b] or [a; b] interchangeably.
    raw = reshape(raw, 1, []);

    n = numel(raw);
    for i = 1:n
        c = raw(i);
        % Re-run the single-channel validator so a hand-built struct gets the
        % same checks as one built by opto_channel.
        assert(all(isfield(c, {'name', 'wavelength', 'fpc', 'slm'})), ...
            'opto_channels:badEntry', ...
            ['rig.opto(%d) is missing required fields. Build entries with ' ...
             'opto_channel():\n  opto_channel(name, wavelength, fpc_module, ' ...
             'slm_module)'], i);
        args = {};
        if isfield(c, 'slm_board'), args = [args, {'slm_board', c.slm_board}]; end %#ok<AGROW>
        if isfield(c, 'slm_lut'),   args = [args, {'slm_lut',   c.slm_lut}];   end %#ok<AGROW>
        if isfield(c, 'label'),     args = [args, {'label',     c.label}];     end %#ok<AGROW>
        c = opto_channel(c.name, c.wavelength, c.fpc, c.slm, args{:});

        c.index      = i;
        c.pool_field = c.name;
        c.holo_field = sprintf('hr%d', c.wavelength);
        c.save_field = sprintf('stim_%d', c.wavelength);

        chans(i) = c; %#ok<AGROW>
    end

    local_check_modules(rig, chans);
    local_check_power(rig, chans);
    local_check_unique_names(chans);
    local_check_module_reuse(chans);
    local_check_rotators(rig, chans);
    local_check_boards(chans);
end

% -------------------------------------------------------------------------
function chans = local_empty()
%LOCAL_EMPTY A 0x0 struct array with the full field set, so callers can do
%   numel(), arrayfun() and {chans.name} on a rig with no lasers.
    chans = struct('name', {}, 'wavelength', {}, 'fpc', {}, 'slm', {}, ...
                   'slm_board', {}, 'slm_lut', {}, 'label', {}, ...
                   'index', {}, 'pool_field', {}, 'holo_field', {}, 'save_field', {});
end

function s = local_cell_to_struct(c)
    s = local_empty();
    for i = 1:numel(c)
        e = c{i};
        assert(isstruct(e) && isscalar(e), 'opto_channels:badTable', ...
            'rig.opto{%d} must be a scalar struct from opto_channel().', i);
        f = fieldnames(e)';
        for k = f
            s(i).(k{1}) = e.(k{1}); %#ok<AGROW>
        end
    end
end

function local_check_modules(rig, chans)
%LOCAL_CHECK_MODULES Every referenced module must actually be declared.
%   Without this, a rig can name fpc_920 in its opto table, pass every existing
%   load_rig check, and then have that laser never armed, never gated and never
%   saved -- the silent-drop failure this table exists to prevent.
    has_modules = isfield(rig, 'modules') && isstruct(rig.modules);
    declared = {};
    if has_modules
        declared = fieldnames(rig.modules)';
    end
    for i = 1:numel(chans)
        c = chans(i);
        for which = {'fpc', 'slm'}
            m = c.(which{1});
            assert(has_modules && isfield(rig.modules, m), ...
                'opto_channels:noModule', ...
                ['Opto channel ''%s'' names %s module ''%s'', which rig.modules ' ...
                 'does not declare.\nDeclared modules: %s\nAdd ' ...
                 'rig.modules.%s, or correct the channel.'], ...
                c.name, which{1}, m, local_join(declared), m);
        end
    end
end

function local_check_power(rig, chans)
%LOCAL_CHECK_POWER Every channel's fpc must declare a coherent power path.
%   Delegated to power_control_spec, which is the SAME function the factory uses
%   at build time -- so the rules cannot drift between "what load_rig accepts"
%   and "what Experiment.setup can actually construct". Running it here means a
%   malformed power declaration is refused at load_rig time, before any DAQ
%   channel or serial port is opened.
    for i = 1:numel(chans)
        power_control_spec(rig.modules.(chans(i).fpc), chans(i).fpc, chans(i).name);
    end
end

function local_check_unique_names(chans)
    names = {chans.name};
    [u, ~, idx] = unique(names);
    for k = 1:numel(u)
        assert(sum(idx == k) == 1, 'opto_channels:duplicateName', ...
            ['Two opto channels are both named ''%s''. Names are pool field ' ...
             'names, so they\nmust be unique -- an experiment could not address ' ...
             'both.'], u{k});
    end
end

function local_check_module_reuse(chans)
%LOCAL_CHECK_MODULE_REUSE Two channels driving one module is always a mistake.
%   Sharing an fpc would mean two channels commanding one shutter and one
%   half-wave plate with different powers in the same trial; sharing an slm would
%   mean two hologram stacks on one trigger.
    for which = {'fpc', 'slm'}
        vals = {chans.(which{1})};
        [u, ~, idx] = unique(vals);
        for k = 1:numel(u)
            hit = find(idx == k);
            assert(numel(hit) == 1, 'opto_channels:sharedModule', ...
                ['Opto channels %s both use %s module ''%s''. Each channel needs ' ...
                 'its own:\nsharing an fpc means two channels commanding one ' ...
                 'shutter and one half-wave\nplate in the same trial; sharing an ' ...
                 'slm means two hologram stacks on one trigger.'], ...
                local_join({chans(hit).name}), which{1}, u{k});
        end
    end
end

function local_check_rotators(rig, chans)
%LOCAL_CHECK_ROTATORS Distinct half-wave-plate addresses across ALL channels.
%   load_rig does not look at ell14_channel, so two channels can silently point
%   at the same rotator: setting one channel's power would then move the other's
%   attenuator. Keyed on bus#address, since the same address on two different
%   serial buses is two different devices.
    seen = {};
    owner = {};
    for i = 1:numel(chans)
        c = chans(i);
        m = rig.modules.(c.fpc);
        if ~isfield(m, 'ell14_channel') || ~isfield(m, 'serial')
            continue    % not an ELL14-attenuated channel; nothing to collide
        end
        key = sprintf('%s#%s', char(string(m.serial)), local_show(m.ell14_channel));
        hit = find(strcmp(seen, key), 1);
        assert(isempty(hit), 'opto_channels:sharedRotator', ...
            ['Opto channels ''%s'' and ''%s'' both use half-wave plate %s on ' ...
             'serial bus ''%s''.\nSetting one channel''s power would move the ' ...
             'other channel''s attenuator.'], ...
            owner{max(hit, 1)}, c.name, local_show(m.ell14_channel), char(string(m.serial)));
        seen{end+1} = key;   %#ok<AGROW>
        owner{end+1} = c.name; %#ok<AGROW>
    end
end

function local_check_boards(chans)
%LOCAL_CHECK_BOARDS Board resolution must be unambiguous.
%   The holography computer maps wavelength -> SLM board (see get_slm), so two
%   channels at the SAME wavelength cannot both let it derive the board: one
%   board would be driven with two hologram stacks. Such a rig must pin
%   slm_board explicitly. Boards that ARE pinned must be distinct.
    wl = [chans.wavelength];
    for k = unique(wl)
        hit = find(wl == k);
        if numel(hit) < 2
            continue
        end
        for i = hit
            assert(~isempty(chans(i).slm_board), ...
                'opto_channels:sharedWavelengthNoBoard', ...
                ['Opto channels %s are all at %d nm, so the holography computer ' ...
                 'cannot derive\nwhich SLM board each one uses -- it resolves the ' ...
                 'board from the wavelength.\nGive each of them an explicit board: ' ...
                 'opto_channel(''%s'', %d, ..., ''Board'', N).'], ...
                local_join({chans(hit).name}), k, chans(i).name, k);
        end
    end

    pinned = find(~cellfun(@isempty, {chans.slm_board}));
    for a = 1:numel(pinned)
        for b = a+1:numel(pinned)
            i = pinned(a); j = pinned(b);
            assert(chans(i).slm_board ~= chans(j).slm_board, ...
                'opto_channels:sharedBoard', ...
                ['Opto channels ''%s'' and ''%s'' both pin SLM board %s. One board ' ...
                 'cannot hold two\nhologram stacks.'], ...
                chans(i).name, chans(j).name, local_show(chans(i).slm_board));
        end
    end
end

% -------------------------------------------------------------------------
function s = local_join(c)
    if isempty(c)
        s = '<none>';
        return
    end
    s = strjoin(cellfun(@(x) sprintf('''%s''', x), c, 'UniformOutput', false), ', ');
end

function s = local_show(v)
    if ischar(v) || isstring(v)
        s = char(v);
    else
        s = mat2str(v);
    end
end

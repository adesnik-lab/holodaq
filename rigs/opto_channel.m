function ch = opto_channel(name, wavelength, fpc, slm, varargin)
%OPTO_CHANNEL Declare one optogenetic stimulation channel for a rig file.
%   ch = OPTO_CHANNEL(name, wavelength, fpc, slm) declares a channel called
%   `name`, at `wavelength` nm, driven by the rig modules `fpc` (power control +
%   shutter) and `slm` (hologram trigger).
%
%   ch = OPTO_CHANNEL(..., 'Board', b, 'Lut', f) additionally pins the SLM board
%   index and its lookup-table file on the holography computer.
%
%   Both identifiers matter and NEITHER is an alias:
%     * `name` is the field an experiment writes in its pool, e.g. a channel
%       named 'red' is commanded by params.pool(i).red. It is what disambiguates
%       two arms that share one wavelength (one laser split across two SLMs).
%     * `wavelength` DERIVES the holoRequest field (hr<nm>) and the saved stim
%       field (stim_<nm>). It is never typed twice, so a channel cannot be wired
%       to one wavelength's hardware and another's calibration.
%
%   A rig with ONE channel is the common case and needs nothing special:
%
%       rig.opto = opto_channel('opto', 1030, 'fpc_1030', 'slm_1030');
%
%   Two channels are declared as an array, in the order holoRequests are
%   transferred to the holography computer:
%
%       rig.opto = [ opto_channel('blue', 900,  'fpc_900',  'slm_900')
%                    opto_channel('red',  1100, 'fpc_1100', 'slm_1100') ];
%
%   Validation here covers ONE channel in isolation. Cross-channel rules
%   (duplicate names, module reuse, shared rotator addresses, two channels at one
%   wavelength) are enforced by opto_channels, which load_rig calls.
%
%   See also: opto_channels, opto_signature, load_rig, ExampleRig

    p = inputParser;
    p.FunctionName = 'opto_channel';
    p.addParameter('slm_board', []);  % [] = holo computer derives it from wavelength
    p.addParameter('slm_lut', '');    % '' = holo computer uses its default LUT
    p.addParameter('label', '');      % '' = '<name> (<nm>nm)'
    p.parse(varargin{:});
    o = p.Results;

    name = local_char(name, 'name');
    fpc  = local_char(fpc,  'fpc');
    slm  = local_char(slm,  'slm');

    % The name becomes a struct field on params.pool, so it must be a legal
    % MATLAB identifier -- otherwise the failure surfaces much later, as an
    % obscure dynamic-field error inside the trial loop.
    assert(isvarname(name), 'opto_channel:badName', ...
        ['Opto channel name ''%s'' is not a valid MATLAB field name.\n' ...
         'It is used directly as a pool field (params.pool(i).%s), so it must ' ...
         'start with a\nletter and contain only letters, digits and ' ...
         'underscores.'], name, name);

    % Reserved pool field names. 'vis' is the visual stimulus (and how
    % make_experiment tells the flavours apart); 'type' is ALREADY used as a
    % label by existing experiments, so a channel called 'type' would collide
    % with live data; 'opto' is kept free for the nested per-channel form.
    assert(~ismember(name, {'vis', 'opto', 'type'}), 'opto_channel:reservedName', ...
        ['Opto channel name ''%s'' is reserved. pool.vis is the visual stimulus, ' ...
         'pool.type is\nalready used as a label by existing experiments, and ' ...
         'pool.opto is kept free for\nthe nested per-channel form.'], name);

    assert(isnumeric(wavelength) && isscalar(wavelength) && isfinite(wavelength) ...
           && wavelength > 0 && mod(wavelength, 1) == 0, ...
        'opto_channel:badWavelength', ...
        ['Wavelength for channel ''%s'' must be a positive whole number of nm ' ...
         '(got %s).\nIt is formatted into the field names hr<nm> and stim_<nm>, ' ...
         'so a fractional\nvalue would produce names no experiment can write.'], ...
        name, local_show(wavelength));

    assert(~isempty(fpc), 'opto_channel:noFpc', ...
        ['Channel ''%s'' needs the name of its power-control module (a ' ...
         'rig.modules entry),\ne.g. ''fpc_%d''.'], name, wavelength);
    assert(~isempty(slm), 'opto_channel:noSlm', ...
        ['Channel ''%s'' needs the name of its SLM module (a rig.modules entry), ' ...
         'e.g. ''slm_%d''.\nEvery opto channel is holographic: the power model ' ...
         'converts power_per_cell to\nwatts using the diffraction efficiency the ' ...
         'holography computer returns, so a\nchannel with no SLM has no way to ' ...
         'compute its power.'], name, wavelength);

    board = o.slm_board;
    if ~isempty(board)
        assert(isnumeric(board) && isscalar(board) && isreal(board) && ...
               board >= 0 && mod(board, 1) == 0, 'opto_channel:badBoard', ...
            'slm_board for channel ''%s'' must be [] or a non-negative integer.', name);
        board = double(board);
    end

    label = local_char(o.label, 'label');
    if isempty(label)
        label = sprintf('%s (%dnm)', name, wavelength);
    end

    % Field name AND order are fixed here: MATLAB refuses to concatenate structs
    % whose fields differ in either, so [a, b] in a rig file only works if every
    % entry comes out of this one constructor.
    ch = struct( ...
        'name',       name, ...
        'wavelength', double(wavelength), ...
        'fpc',        fpc, ...
        'slm',        slm, ...
        'slm_board',  board, ...
        'slm_lut',    local_char(o.slm_lut, 'slm_lut'), ...
        'label',      label);
end

% -------------------------------------------------------------------------
function s = local_char(v, what)
    if isstring(v) || ischar(v)
        s = char(v);
        s = strtrim(s);
    elseif isempty(v)
        s = '';
    else
        error('opto_channel:badType', ...
            'Opto channel %s must be text (char or string), got %s.', what, class(v));
    end
end

function s = local_show(v)
    try
        s = mat2str(v);
    catch
        s = class(v);
    end
end

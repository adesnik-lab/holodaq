function payload = publish_rig_config(varargin)
%PUBLISH_RIG_CONFIG Publish this rig's satellite-relevant config over holochat.
%   The rig file on the DAQ is the single source of truth for the whole scope.
%   The other three machines (ScanImage, holography, PsychoPy) cannot read it:
%   Python cannot call load_rig at all, and neither MATLAB satellite calls it
%   today, so every rig_get(...) on those boxes silently takes its fallback.
%   This posts the parts they need to the persistent holochat config topic
%   'rig', which every machine can already read.
%
%   payload = PUBLISH_RIG_CONFIG()              publish the loaded rig
%   payload = PUBLISH_RIG_CONFIG('Rig', rig)    publish a specific rig struct
%   payload = PUBLISH_RIG_CONFIG('DryRun',true) build and return, post nothing
%   ... ('Topic','rig')  ... ('Comm', holochat)  override the topic / interface
%
%   Safe to call repeatedly: set_config overwrites the topic, and a config topic
%   is persistent and non-consuming, so satellites may start in any order and
%   still read the latest value. Read it back with rig_remote_get.
%
%   THE PAYLOAD IS DELIBERATELY FLAT. Keys are dotted rig paths with '.' replaced
%   by '_' ('paths.calib_dir' -> paths_calib_dir), because the PsychoPy box reads
%   this through SimpleHolochatReader.decode, which unwraps exactly ONE level
%   (output[k] = v[0]['mwdata'][:]). A nested struct would reach Python as raw
%   mwtype-tagged data rather than a usable value. rig_remote_get hides the
%   flattening, so callers still use dotted paths exactly as with rig_get.
%
%   Three rules keep this from shipping something harmful:
%     - EMPTY VALUES ARE NEVER PUBLISHED. An empty published as authoritative is
%       worse than absence, because it would override a satellite's own correct
%       literal. Skipping lets the satellite fall through to its local value.
%     - MACHINE-SCOPED LEAVES ARE NEVER PUBLISHED (the DENY list below):
%       paths.matlab_paths is the DAQ's own addpath list, including a genpath of
%       that machine's code tree; network.remote_api is a 127.0.0.1 URL. Both are
%       correct only on the machine that wrote them.
%     - ONLY char / numeric / logical LEAVES GO ON THE WIRE. Anything else -- a
%       cell, a struct array, a function handle -- is skipped and reported rather
%       than silently mangled by the JSON transport.
%
%   See also: rig_remote_get, load_rig, prime_info, HolochatInterface.set_config

    p = inputParser;
    p.addParameter('Rig', []);
    p.addParameter('Comm', []);
    p.addParameter('Topic', 'rig');
    p.addParameter('DryRun', false);
    p.parse(varargin{:});
    opt = p.Results;

    rig = opt.Rig;
    if isempty(rig)
        rig = load_rig();
    end

    % Groups published wholesale (flattened). rig.modules is NOT here: most of it
    % is DAQ-side wiring the satellites must not act on, so only the entries a
    % satellite genuinely needs are added explicitly below.
    GROUPS = {'paths', 'serial', 'holo', 'ptb', 'network'};
    % network.remote_api is loopback-scoped: validate_rig defaults it to
    % http://127.0.0.1:<port>/api, which on any other machine points at that
    % machine's own (absent) webapp rather than the DAQ's. Same class of hazard
    % as matlab_paths -- a value that is correct only where it was written.
    DENY   = {'paths.matlab_paths', 'network.remote_api'};

    payload = struct();
    payload.rig_protocol = 'rig/1';
    payload.rig_name     = char(rig.name);
    payload.published_by = local_hostname();
    payload.published_at = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

    skipped = {};
    for g = GROUPS
        if isfield(rig, g{1}) && isstruct(rig.(g{1}))
            [payload, skipped] = local_flatten(rig.(g{1}), g{1}, DENY, payload, skipped);
        end
    end

    % rig.modules is deliberately NOT published at all. It is DAQ-side wiring --
    % digital lines, analog channels, ELL14 rotator addresses -- that no satellite
    % should act on. The PsychoPy box's settings live in rig.ptb (published above
    % with the other groups); the holography box's in rig.opto and rig.holo.

    % The opto channel table, for the holography computer's SLM inventory. It
    % needs board + LUT at STARTUP, before any prime arrives, because a Meadowlark
    % board cannot safely be reopened per experiment -- which is exactly why this
    % belongs in persistent config rather than in the per-experiment prime.
    %
    % Flattened to opto_<i>_<field>, NOT sent as a struct array. prime_info does
    % send a struct array, but whether Python's one-level decode survives that
    % depends on how mps.json encodes a struct-array field, which is unverified
    % here -- and if it does not, the failure is a TypeError that takes down the
    % whole read_config, not just this field. Flat keys cost one loop and remove
    % the question. rig_remote_get('opto') reassembles the ordered table.
    t = opto_channels(rig);
    payload.n_channels     = numel(t);
    payload.opto_signature = opto_signature(t);
    for i = 1:numel(t)
        pre = sprintf('opto_%d_', i);
        payload.([pre 'name'])       = char(t(i).name);
        payload.([pre 'wavelength']) = double(t(i).wavelength);
        % Omitted when unset: absence means "let the holo computer derive it",
        % which is the same meaning [] / '' carries in the rig file.
        if ~isempty(t(i).slm_board)
            payload.([pre 'slm_board']) = double(t(i).slm_board);
        end
        if ~isempty(t(i).slm_lut)
            payload.([pre 'slm_lut']) = char(t(i).slm_lut);
        end
    end

    if opt.DryRun
        local_report(payload, skipped, opt.Topic, true);
        return
    end

    comm = opt.Comm;
    if isempty(comm)
        % reset=false: constructing this must not wipe any topic. The default
        % (true) would DELETE the sender's own db entry on the broker.
        comm = HolochatInterface('daq', [], false);
    end
    comm.set_config(payload, opt.Topic);
    local_report(payload, skipped, opt.Topic, false);
end


function [flat, skipped] = local_flatten(s, prefix, deny, flat, skipped)
%LOCAL_FLATTEN Recursively flatten a scalar struct into <a>_<b>_<c> keys.
%   Only char / numeric / logical leaves are published. Anything else (a cell,
%   a struct array, a function handle) is skipped and reported rather than
%   silently mangled by the JSON transport.
    for f = reshape(fieldnames(s), 1, [])
        name   = f{1};
        dotted = name;
        if ~isempty(prefix)
            dotted = [prefix '.' name];   %#ok<AGROW>
        end
        v = s.(name);

        if any(strcmp(dotted, deny))
            skipped{end+1} = sprintf('%-28s machine-scoped, never published', dotted); %#ok<AGROW>
            continue
        end
        if isstruct(v) && isscalar(v)
            [flat, skipped] = local_flatten(v, dotted, deny, flat, skipped);
            continue
        end
        if isempty(v)
            skipped{end+1} = sprintf('%-28s empty (satellite keeps its own value)', dotted); %#ok<AGROW>
            continue
        end
        if ischar(v) || isstring(v)
            flat.(local_key(dotted)) = char(v);
        elseif isnumeric(v) || islogical(v)
            flat.(local_key(dotted)) = v;
        else
            skipped{end+1} = sprintf('%-28s unsupported on the wire (%s)', dotted, class(v)); %#ok<AGROW>
        end
    end
end


function k = local_key(dotted)
    k = strrep(dotted, '.', '_');
end



function h = local_hostname()
    h = getenv('COMPUTERNAME');
    if isempty(h), h = getenv('HOSTNAME'); end
    if isempty(h)
        try
            [st, out] = system('hostname');
            if st == 0, h = strtrim(out); end
        catch
        end
    end
    if isempty(h), h = 'unknown'; end
    h = char(h);
end


function local_report(payload, skipped, topic, dry)
    keys = setdiff(reshape(fieldnames(payload), 1, []), ...
        {'rig_protocol', 'rig_name', 'published_by', 'published_at'});
    if dry
        fprintf('publish_rig_config (DRY RUN -- nothing posted)\n');
    else
        fprintf('publish_rig_config -> config/%s\n', topic);
    end
    fprintf('  rig %s from %s at %s\n', ...
        payload.rig_name, payload.published_by, payload.published_at);
    fprintf('  %d value(s) + %d opto channel(s) [%s]\n', ...
        numel(keys), payload.n_channels, payload.opto_signature);
    for k = sort(keys)
        v = payload.(k{1});
        if ischar(v)
            fprintf('    %-32s %s\n', k{1}, v);
        else
            fprintf('    %-32s %s\n', k{1}, mat2str(v));
        end
    end
    if ~isempty(skipped)
        fprintf('  not published:\n');
        for i = 1:numel(skipped)
            fprintf('    %s\n', skipped{i});
        end
    end
end

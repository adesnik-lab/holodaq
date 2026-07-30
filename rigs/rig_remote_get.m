function out = rig_remote_get(path, fallback)
%RIG_REMOTE_GET Read a rig config value on a satellite machine.
%   Same dotted-path interface as RIG_GET, but resolved in this order:
%
%       1. holochat config/rig   (published by the DAQ via publish_rig_config)
%       2. a local load_rig      (if this machine happens to have a rig file)
%       3. the fallback argument (the literal that was hardcoded before)
%
%   out = RIG_REMOTE_GET('paths.calib_dir', 'C:\Users\holos\Documents\calibs')
%   out = RIG_REMOTE_GET()          the whole published payload ([] if none)
%   out = RIG_REMOTE_GET('refresh') drop the cache, re-read, return the payload
%
%   Why the DAQ wins: it is the only machine guaranteed to have a rig file
%   (rig_hardware calls load_rig unconditionally), so it is the single source of
%   truth. A satellite's own rig file, if any, is a fallback for a cold broker --
%   not an equal authority. Nothing here opens hardware, so it is safe to call
%   from a listener's startup path.
%
%   The payload is fetched ONCE per session and cached, so this is cheap in a
%   loop. Call RIG_REMOTE_GET('refresh') after re-publishing on the DAQ, or just
%   restart the listener.
%
%   A cold broker is not an error: you get the fallback plus one warning naming
%   publish_rig_config. That is deliberate -- a satellite must still come up on
%   its old literals rather than refuse to start.
%
%   See also: publish_rig_config, rig_get, load_rig

    persistent cache fetched tried_local warned_cold

    if nargin >= 1 && ischar(path) && strcmp(path, 'refresh')
        cache = []; fetched = false; tried_local = false; warned_cold = false;
    end

    if isempty(fetched) || ~fetched
        cache   = local_fetch();
        fetched = true;
        if isempty(cache)
            if isempty(warned_cold) || ~warned_cold
                warning('rig_remote_get:noConfig', ...
                    ['Nothing published on holochat config/rig, so this machine ' ...
                     'is running on\nits own local values. To fix: run ' ...
                     '''publish_rig_config()'' on the DAQ, then\n' ...
                     '''rig_remote_get(''''refresh'''')'' here (or restart this ' ...
                     'listener).']);
                warned_cold = true;
            end
        else
            fprintf('rig_remote_get: rig ''%s'' published %s by %s [%s]\n', ...
                local_opt(cache, 'rig_name', '<unnamed>'), ...
                local_opt(cache, 'published_at', '?'), ...
                local_opt(cache, 'published_by', '?'), ...
                local_opt(cache, 'opto_signature', '?'));
        end
    end

    % No path (or 'refresh'): hand back the whole payload.
    if nargin == 0 || (ischar(path) && strcmp(path, 'refresh'))
        out = cache;
        return
    end

    % 'opto' reassembles the ordered channel table from the flat opto_<i>_*
    % keys publish_rig_config emits. This is what the holography computer needs
    % at startup to build its SLM inventory, before any prime arrives.
    if ischar(path) && strcmp(path, 'opto')
        out = local_opto(cache);
        if isempty(out) && nargin >= 2
            out = fallback;
        end
        return
    end

    % 1. published config. Empties are never published (publish_rig_config skips
    %    them), so a present key is always a real value.
    key = strrep(path, '.', '_');
    if isstruct(cache) && isfield(cache, key) && ~isempty(cache.(key))
        out = cache.(key);
        return
    end

    % 2. a local rig file, if this machine has one. Attempted once per session:
    %    load_rig is hardware-free but it prints, and on most satellites it will
    %    simply fail (no rig file), which is fine and not worth repeating.
    if isempty(tried_local) || ~tried_local
        tried_local = true;
        try
            load_rig();
        catch
            % No rig file here -- expected on a satellite.
        end
    end

    % rig_get reads the cached rig, so this returns the fallback when load_rig
    % above found nothing. Its own error message covers the no-fallback case.
    if nargin < 2
        out = rig_get(path);
    else
        out = rig_get(path, fallback);
    end
end


function payload = local_fetch()
%LOCAL_FETCH One non-blocking read of config/rig. [] if unset or unreachable.
    payload = [];
    try
        % reset=false so constructing this does not DELETE the sender's own topic
        % on the broker, which the default (true) would do.
        comm    = HolochatInterface('rig_reader', [], false);
        payload = comm.scan_config('rig');
    catch err
        warning('rig_remote_get:unreachable', ...
            ['Could not reach the holochat broker, so no published rig config ' ...
             'is available\n(%s).\nFalling back to local values.'], err.message);
        payload = [];
    end
    if ~isempty(payload) && ~isstruct(payload)
        warning('rig_remote_get:badPayload', ...
            'config/rig holds a %s, not a struct. Ignoring it.', class(payload));
        payload = [];
        return
    end
    if ~isempty(payload) && isfield(payload, 'rig_protocol') ...
            && ~strcmp(payload.rig_protocol, 'rig/1')
        warning('rig_remote_get:protocol', ...
            ['config/rig announces protocol ''%s'', but this code speaks ' ...
             '''rig/1''.\nReading it anyway; update the older machine.'], ...
            char(payload.rig_protocol));
    end
end


function t = local_opto(cache)
%LOCAL_OPTO Rebuild the ordered opto table from the flat opto_<i>_* keys.
%   Field set and order match what opto_channels returns for the fields that
%   cross the wire, so a consumer can treat this like a (partial) rig.opto
%   table. slm_board / slm_lut come back empty when the publisher omitted them,
%   which carries the same "let this machine derive it" meaning as in the rig
%   file. Returns a 0x0 table with the full field set when nothing is published,
%   so numel/arrayfun/{t.name} all still work.
    t = struct('name', {}, 'wavelength', {}, 'index', {}, ...
               'slm_board', {}, 'slm_lut', {});
    if ~isstruct(cache) || ~isfield(cache, 'n_channels')
        return
    end
    n = double(cache.n_channels);
    if ~isscalar(n) || ~isfinite(n) || n < 1
        return
    end
    for i = 1:n
        pre = sprintf('opto_%d_', i);
        if ~isfield(cache, [pre 'name']) || ~isfield(cache, [pre 'wavelength'])
            warning('rig_remote_get:optoIncomplete', ...
                ['config/rig announces %d opto channel(s) but channel %d is ' ...
                 'missing from the\npayload. Ignoring the published table; the ' ...
                 'caller falls back to its own.'], n, i);
            t = struct('name', {}, 'wavelength', {}, 'index', {}, ...
                       'slm_board', {}, 'slm_lut', {});
            return
        end
        t(i).name       = char(cache.([pre 'name']));           %#ok<AGROW>
        t(i).wavelength = double(cache.([pre 'wavelength']));   %#ok<AGROW>
        t(i).index      = i;                                    %#ok<AGROW>
        t(i).slm_board  = local_field(cache, [pre 'slm_board'], []);   %#ok<AGROW>
        t(i).slm_lut    = char(local_field(cache, [pre 'slm_lut'], '')); %#ok<AGROW>
    end
end


function v = local_field(s, name, default)
    v = default;
    if isfield(s, name) && ~isempty(s.(name))
        v = s.(name);
    end
end


function v = local_opt(s, name, default)
    v = default;
    if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
        v = s.(name);
        if isnumeric(v) || islogical(v), v = mat2str(v); end
        v = char(v);
    end
end

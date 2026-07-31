function url = holochat_server()
%HOLOCHAT_SERVER Base URL of the holochat broker (the ONE place it resolves).
%   Resolution order:
%     1) the HOLOCHAT_SERVER environment variable, if set;
%     2) else rig.network.holochat_server from a rig loaded this session;
%     3) else the documented Scope2K default.
%
%   WHY THE ENVIRONMENT WINS HERE, unlike every other rig value. This is the
%   bootstrap value: it cannot come from the published config, because you need
%   the broker URL in order to read the config. So the satellites -- which have
%   no rig file, and where rig_get therefore always returns the fallback -- need
%   some mechanism outside the rig, and an env var is the only one that works on
%   all four machines including the Linux PsychoPy box. Making it authoritative
%   keeps ONE rule ("the env var decides") rather than "it depends whether this
%   machine happens to have a rig file".
%
%   The trade is that a stale HOLOCHAT_SERVER could silently split the rig across
%   two brokers, which is a miserable failure to diagnose: the DAQ would publish
%   and prime into one broker while the satellites listen to another, so nothing
%   would arrive and nothing would error. So this announces its source ONCE per
%   MATLAB session. If a machine is not seeing primes, that line says why.
%
%   The Python side reads the same variable (SimpleHolochatReader, ptb_primer),
%   so one export covers a whole machine.
%
%   See also: HolochatInterface, publish_rig_config, rig_remote_get

    persistent announced

    DEFAULT = 'http://136.152.58.120:8000';

    url = strtrim(getenv('HOLOCHAT_SERVER'));
    src = 'the HOLOCHAT_SERVER environment variable';

    if isempty(url)
        try, url = rig_get('network.holochat_server', ''); catch, url = ''; end
        src = 'rig.network.holochat_server';
    end
    if isempty(url)
        url = DEFAULT;
        src = 'the built-in Scope2K default';
    end
    url = char(url);

    if isempty(announced)
        announced = true;
        fprintf('holochat: %s (from %s)\n', url, src);
        if ~contains(url, '://')
            warning('holochat_server:noScheme', ...
                ['The holochat URL ''%s'' has no scheme, so webread will fail ' ...
                 'confusingly.\nUse a full URL, e.g. http://host:8000'], url);
        end
    end
end

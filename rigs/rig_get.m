function val = rig_get(path, fallback)
%RIG_GET Read a value from the loaded rig by dotted path, with a fallback.
%   val = RIG_GET('network.holochat_server', 'http://...') returns the value
%   from the rig loaded via load_rig; if no rig is loaded or the field is
%   absent, the fallback is returned instead. With no fallback argument a
%   missing rig/field is an error.
%
%   Class internals use this for their rig-specific defaults so that machines
%   without a rig file (satellite computers, Simulate-mode GUIs) keep working
%   on the documented fallback values.
%
%   See also LOAD_RIG, RIG_HAS.

    [val, found] = walk(rig_store('get'), path);
    if ~found
        if nargin < 2
            error('rig_get:missing', ...
                ['No rig loaded (or the rig has no ''%s'') and no fallback was ' ...
                 'given. Call load_rig first or add the field to your rig file.'], path);
        end
        val = fallback;
    end
end

function [val, found] = walk(s, path)
    val = [];
    found = false;
    parts = strsplit(path, '.');
    for i = 1:numel(parts)
        if ~isstruct(s) || ~isfield(s, parts{i})
            return
        end
        s = s.(parts{i});
    end
    val = s;
    found = true;
end

function tf = rig_has(rig, name)
%RIG_HAS True if the rig defines a module (or an arbitrary dotted field).
%   rig_has(rig, 'patch')        -> the rig has a modules.patch entry
%   rig_has(rig, 'serial.ell14') -> the dotted path exists in the rig struct
%
%   Module presence in the rig file is the single switch for optional
%   hardware: experiment scripts wrap each module's construction in
%   rig_has(...) so a rig that lacks the hardware simply skips it.
%
%   See also LOAD_RIG, RIG_GET.

    if contains(name, '.')
        s = rig;
        tf = false;
        for part = strsplit(name, '.')
            if ~isstruct(s) || ~isfield(s, part{1})
                return
            end
            s = s.(part{1});
        end
        tf = true;
    else
        tf = isfield(rig, 'modules') && isfield(rig.modules, name);
    end
end

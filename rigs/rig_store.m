function out = rig_store(action, value)
%RIG_STORE Internal persistent store for the loaded rig definition.
%   Not meant to be called directly — use load_rig / rig_get / rig_has.
%
%   rig_store('get')        -> currently loaded rig struct, or [] if none
%   rig_store('set', rig)   -> cache a rig struct
%   rig_store('clear')      -> forget the loaded rig
%
%   Note: `clear functions` wipes the cache; the next load_rig() re-resolves.

    persistent rig

    out = [];
    switch action
        case 'get'
            out = rig;
        case 'set'
            rig = value;
            out = rig;
        case 'clear'
            rig = [];
        otherwise
            error('rig_store:action', 'Unknown action ''%s''.', action);
    end
end

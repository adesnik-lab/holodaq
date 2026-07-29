function r = stim_data_root()
%STIM_DATA_ROOT Effective stim-data save root (the ONE place save paths resolve).
%   Resolution order:
%     1) the active profile's save root, if the ExperimentLauncher has set one
%        (pref group 'Scope2kProfile', key 'save_root') — this is how a profile
%        overrides where data is saved;
%     2) else rig.paths.data_root from the loaded rig (rig_get);
%     3) else the documented default 'K://KKS//stim-data' — this warns, since
%        nothing on this machine said where its data belongs.
%
%   Framework save paths (Saver, save_holoinfo, the launcher's overwrite/holo
%   checks) call this so they follow the active profile. Experiment runners that
%   build their own K:\ paths should adopt this too as they're updated.
%
%   See also: rig_get, ExperimentLauncher (applySaveRoot / currentSaveRoot).

    r = '';
    try, r = getpref('Scope2kProfile', 'save_root', ''); catch, end
    if isempty(r)
        try, r = rig_get('paths.data_root', ''); catch, end
    end
    if isempty(r)
        r = 'K://KKS//stim-data';
        warning('stim_data_root:default', ...
            ['No profile save root and no rig.paths.data_root — falling back to\n' ...
             '''%s''. Set paths.data_root in your rig file if that is not this\n' ...
             'machine''s data drive.'], r);
    end
end

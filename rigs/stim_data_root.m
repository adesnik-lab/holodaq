function r = stim_data_root()
%STIM_DATA_ROOT Effective stim-data save root (the ONE place save paths resolve).
%   Resolution order:
%     1) the active profile's save root, if the ExperimentLauncher has set one
%        (pref group 'Scope2kProfile', key 'save_root') — this is how a profile
%        overrides where data is saved;
%     2) else rig.paths.data_root from the loaded rig (rig_get);
%     3) else the documented default 'K://KKS//stim-data', with a
%        'stim_data_root:default' warning — reaching this on a rig machine means
%        the save root is unconfigured, which is otherwise silent until data
%        lands somewhere unexpected.
%
%   Framework save paths (Saver, save_holoinfo, the launcher's overwrite/holo
%   checks) call this so they follow the active profile. Experiment runners that
%   build their own K:\ paths should adopt this too as they're updated.
%
%   See also: rig_get, ExperimentLauncher (applySaveRoot / currentSaveRoot).

    r = '';
    try, r = getpref('Scope2kProfile', 'save_root', ''); catch, end
    if ~isempty(r)
        return
    end

    % No fallback to rig_get on purpose: a rig may legitimately set data_root to
    % the same literal as the default (Scope2KRig does), so the missing-field
    % error is the only reliable signal that we really are falling through.
    try
        r = rig_get('paths.data_root');
        return
    catch
    end

    r = 'K://KKS//stim-data';
    warning('stim_data_root:default', ...
        ['No profile save root and no rig.paths.data_root: falling back to ' ...
         '''%s''. Set a save root in the ExperimentLauncher, or add ' ...
         'paths.data_root to your rig file.'], r);
end

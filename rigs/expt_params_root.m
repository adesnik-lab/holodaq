function r = expt_params_root()
%EXPT_PARAMS_ROOT Folder for experiment parameter files (the ONE place they resolve).
%   Holds the per-run <date>_<mouse>_<epoch><experiment>_experiment_parameters.json
%   that save_params writes, the .mat OnlineSession saves, and the folder
%   run_experiment cd's into so a runner's uigetfile starts somewhere useful.
%
%   Resolution order:
%     1) rig.paths.expt_params from the loaded rig (rig_get);
%     2) else the documented default 'K:/KKS/expt-params' -- this warns, since
%        nothing on this machine said where its parameter files belong.
%
%   NOTE: unlike STIM_DATA_ROOT this does NOT follow the active launcher profile.
%   A profile's save_root redirects DATA; parameter files stay in one place per
%   rig so a session's params are findable regardless of who ran it. If you want
%   per-profile params, add a pref here the way stim_data_root does -- but decide
%   deliberately, because it changes where every past run's params are looked for.
%
%   On Scope2K this is a SIBLING of the stim-data root, not a child of it, which
%   is why it is its own rig field rather than derived from paths.data_root.
%
%   See also: stim_data_root, rig_get, save_params, run_experiment, OnlineSession

    r = '';
    try, r = rig_get('paths.expt_params', ''); catch, end
    if isempty(r)
        r = 'K:/KKS/expt-params';
        warning('expt_params_root:default', ...
            ['No rig.paths.expt_params -- falling back to\n''%s''. Set ' ...
             'paths.expt_params in your rig file if that is not where this\n' ...
             'machine''s experiment parameter files belong.'], r);
    end
end

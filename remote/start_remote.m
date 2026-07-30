function agent = start_remote(varargin)
%START_REMOTE Dev/simulate convenience: one process driving BOTH the power GUI
%   and the ExperimentLauncher (role 'both').
%
%   On the RIG use the two separate entry points instead — they must not share
%   the DAQ/COM4 ports at the same time:
%       ScopeController('Token', <PIN>)     % laser / shutter / power
%       ExperimentLauncher('Token', <PIN>)  % experiments
%   start_remote bundles both in one process, which is only safe with
%   'Simulate', true (no hardware). It remains handy for off-rig UI testing.
%
%   agent = START_REMOTE() connects to http://127.0.0.1:8765/api, creates an
%   ExperimentLauncher + PowerControllerCalibrated, and starts polling the
%   phone-control server. Keep the returned handle; call agent.stop() to end.
%
%   Name-value options:
%     'Base'        server API base URL (default 'http://127.0.0.1:<Port>/api')
%     'Port'        localhost port for the default base URL   (default 8765)
%     'Token'       shared PIN/token; MUST match server config.json (default '1234')
%     'Simulate'    true = no hardware + fake run, for off-rig testing (default false)
%     'Visible'     show the PowerControllerCalibrated window   (default true)
%     'Experiments' create an ExperimentLauncher for run control (default true).
%            Requires the holoexpt repo on the path; warns and continues with
%            power control only if it is absent.
%     'Launcher'    an existing launcher object to drive instead of constructing
%            one. Preferred: it keeps holodaq independent of holoexpt.
%
%   Examples:
%     ag = start_remote('Token', '8261');                    % on the rig PC
%     ag = start_remote('Simulate', true, 'Visible', false); % on a laptop
%
%   See also RemoteControlAgent, RemoteControlIO, PowerControllerCalibrated,
%            ExperimentLauncher.

    % Ensure the remote classes, the rig classes, and rigs/ are on the path
    % (the rig_get default below needs rigs/).
    here = fileparts(mfilename('fullpath'));   % holodaq/remote
    addpath(here);
    addpath(fileparts(here));                  % holodaq (PowerControllerCalibrated, ...)
    addpath(fullfile(fileparts(here), 'rigs'));

    p = inputParser;
    p.addParameter('Base', '');
    p.addParameter('Port', rig_get('network.remote_port', 8765));
    p.addParameter('Token', '1234');
    p.addParameter('Simulate', false);
    p.addParameter('Visible', true);
    p.addParameter('Experiments', true);
    p.addParameter('Launcher', []);   % an ExperimentLauncher (holoexpt); [] to construct one
    p.parse(varargin{:});
    r = p.Results;

    if ~logical(r.Simulate)
        warning(['start_remote runs the power GUI + launcher in ONE process ' ...
            '(they share the HWP serial port on real hardware). On the rig use ' ...
            'ScopeController and ExperimentLauncher separately instead.']);
    end

    base = r.Base;
    if isempty(base)
        base = sprintf('http://127.0.0.1:%d/api', r.Port);
    end

    io = RemoteControlIO(base, r.Token);

    % The launcher lives in holoexpt, not here, so holodaq must not name the
    % class: pass one in with 'Launcher', or let it be constructed only when
    % ExperimentLauncher happens to be on the path. RemoteControlAgent takes it
    % as a duck-typed parameter, so holodaq stays independently usable.
    launcher = r.Launcher;
    if isempty(launcher) && logical(r.Experiments) && ~logical(r.Simulate)
        % 'class' alone can miss a classdef .m that MATLAB has not loaded yet,
        % so accept either answer.
        if exist('ExperimentLauncher', 'class') == 8 || ...
           exist('ExperimentLauncher', 'file') == 2
            fn = str2func('ExperimentLauncher');
            launcher = fn();                   % opens the launcher window (real hardware)
        else
            warning('start_remote:noLauncher', ...
                ['Experiments were requested but ExperimentLauncher is not on the ' ...
                 'path. Add the holoexpt repo, or pass ''Launcher'', <obj>. ' ...
                 'Continuing with power control only.']);
        end
    end

    agent = RemoteControlAgent(io, ...
        'Simulate', logical(r.Simulate), ...
        'Visible',  logical(r.Visible), ...
        'Launcher', launcher);
    agent.start();

    fprintf(['\nRemote bridge running.\n' ...
             '  Server : %s\n' ...
             '  Phone  : browse to the server host on the same WiFi and enter the PIN.\n' ...
             '  Stop   : agent.stop()   (or clear the returned variable)\n\n'], base);
end

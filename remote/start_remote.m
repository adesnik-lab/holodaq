function agent = start_remote(varargin)
%START_REMOTE Launch the phone remote-control bridge for the scope2k rig.
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
%     'Experiments' create an ExperimentLauncher for run control (default true)
%
%   Examples:
%     ag = start_remote('Token', '8261');                    % on the rig PC
%     ag = start_remote('Simulate', true, 'Visible', false); % on a laptop
%
%   See also RemoteControlAgent, RemoteControlIO, PowerControllerCalibrated,
%            ExperimentLauncher.

    p = inputParser;
    p.addParameter('Base', '');
    p.addParameter('Port', 8765);
    p.addParameter('Token', '1234');
    p.addParameter('Simulate', false);
    p.addParameter('Visible', true);
    p.addParameter('Experiments', true);
    p.parse(varargin{:});
    r = p.Results;

    base = r.Base;
    if isempty(base)
        base = sprintf('http://127.0.0.1:%d/api', r.Port);
    end

    % Ensure the remote classes and the rig classes are on the path.
    here = fileparts(mfilename('fullpath'));   % holodaq/remote
    addpath(here);
    addpath(fileparts(here));                  % holodaq (PowerControllerCalibrated, ...)

    io = RemoteControlIO(base, r.Token);

    launcher = [];
    if logical(r.Experiments) && ~logical(r.Simulate)
        launcher = ExperimentLauncher();       % opens the launcher window (real hardware)
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

function ctl = ScopeController(varargin)
%SCOPECONTROLLER Launch ONLY the laser/shutter/power GUI (PowerControllerCalibrated),
%   optionally connected to the phone webapp as the 'scope' client.
%
%   Run this INSTEAD of ExperimentLauncher — the two GUIs must not run at the
%   same time because they share the DAQ + COM4 serial ports.
%
%   ScopeController()                       just the GUI, local only
%   ScopeController('Token','8261')         also connect to the webapp (scope role)
%   ScopeController('Base',url,'Token',tok,'Port',p)
%   ScopeController('Simulate',true,'Visible',false)   off-rig testing
%
%   Returns a struct with:
%       .app    the PowerControllerCalibrated GUI
%       .agent  the RemoteControlAgent ([] if local only) — agent.stop() to disconnect
%
%   See also PowerControllerCalibrated, RemoteControlAgent, ExperimentLauncher.

    here = fileparts(mfilename('fullpath'));   % holodaq
    addpath(here);
    addpath(fullfile(here, 'remote'));
    addpath(fullfile(here, 'rigs'));           % rig_get below needs rigs/

    p = inputParser;
    p.addParameter('Base', '');
    p.addParameter('Port', rig_get('network.remote_port', 8765));
    p.addParameter('Token', '');
    p.addParameter('Simulate', false);
    p.addParameter('Visible', true);
    p.parse(varargin{:});
    r = p.Results;

    app = PowerControllerCalibrated('Simulate', logical(r.Simulate), ...
                                    'Visible',  logical(r.Visible));

    agent = [];
    if ~isempty(r.Token) || ~isempty(r.Base)
        base = r.Base;
        if isempty(base), base = sprintf('http://127.0.0.1:%d/api', r.Port); end
        io = RemoteControlIO(base, r.Token);
        % Reuse the SAME power app the user sees; scope role never touches the
        % experiment launcher, so there is no hardware handoff here.
        agent = RemoteControlAgent(io, 'Role', 'scope', 'Power', app, ...
            'Simulate', logical(r.Simulate), 'Visible', logical(r.Visible));
        agent.start();
        fprintf('ScopeController connected to %s (scope role). agent.stop() to disconnect.\n', base);
    else
        fprintf('ScopeController running locally (no webapp).\n');
    end

    ctl = struct('app', app, 'agent', agent);
    if nargout == 0, clear ctl; end
end

function r = start_si_listener(varargin)
%START_SI_LISTENER Run once on the ScanImage computer's MATLAB session.
%   Starts a persistent listener that primes ScanImage for each experiment the
%   DAQ master prepares: sets the save filename (matching the DAQ Saver stem),
%   enables logging + external trigger, enables the experiment's user function,
%   and arms acquisition. Leave it running all session; it re-primes on every
%   Prepare. Requires hSI and hSICtl in the base workspace (ScanImage running).
%
%   ASYNC BY DEFAULT (changed 2026-08-05). The listener runs on a timer and the
%   MATLAB prompt stays usable. This matters more here than on any other box: hSI
%   lives in this session's base workspace and no other process can reach it, so
%   the blocking listener cost the only session able to touch ScanImage.
%
%   A small status window opens with it (SIListenerMonitor): a lamp saying whether
%   the listener is listening / starved / stopped, and one Start/Stop button. The
%   async listener is otherwise invisible -- see below on what async does not give
%   you. CLOSING THAT WINDOW STOPS THE LISTENER; 'nogui' skips it entirely, which is
%   what the tests and any headless invocation want.
%
%   Usage (on the SI computer):
%       r = start_si_listener               % async; tiff root from the rig
%       r = start_si_listener('E:')         % async; override the root
%       r = start_si_listener('nogui')      % async, no status window
%       r = start_si_listener('blocking')   % old behaviour: owns the session, Ctrl-C
%       r = start_si_listener('E:', 'blocking')
%
%       r.status()        % am I actually listening? also flags a starved timer
%       r.stop()          % halt the async listener
%       r.listen_async()  % start it again
%       SIListenerMonitor(r)   % re-open the status window
%
%   WHAT ASYNC DOES NOT GIVE YOU: an uninterrupted session, only a usable one.
%   Timer callbacks run on MATLAB's event queue, serviced when MATLAB is idle or at
%   pause/drawnow/waitfor, so a long blocking operation at the prompt DELAYS
%   priming -- r.status() reports the achieved period and says when it is starved.
%   And a prime can land in the middle of your work: SIReceiver.run aborts and
%   re-arms ScanImage and swaps user functions, and onFinish can hold a tick for up
%   to 60 s. Do not hand-drive hSI while a prime may arrive. Use 'blocking' when
%   you want the guarantee that nothing else in this session can interfere.
%
%   With no root argument the tiff root comes from rig.paths.si_root, resolved via
%   rig_remote_get: the config the DAQ published to holochat, else a rig file on
%   this machine, else 'D:'. The receiver prints which one it used. An explicit
%   argument always wins, so the old start_si_listener('E:') behaviour is intact.
%
%   See also SIReceiver, SIListenerMonitor, Receiver/listen_async, Receiver/status,
%   Receiver/stop, prime_info, publish_rig_config.

    % Tiff root stays positional, 'blocking'/'async'/'gui'/'nogui' are keywords in any
    % position. Split out into its own function so it is testable -- the addpath below
    % prepends the real receivers, so a stub SIReceiver cannot shadow them from a test.
    [si_root, mode, gui] = parse_si_listener_args(varargin{:});

    here = fileparts(mfilename('fullpath'));   % holodaq/receivers
    addpath(genpath(fileparts(here)));         % put holodaq (HolochatInterface, ...) on path

    r = SIReceiver(si_root);
    if strcmp(mode, 'blocking')
        if gui
            % Blocking mode wins over the window: listen() is a while-true loop, so
            % a Stop button could never interrupt it -- only Ctrl-C can.
            fprintf('SIReceiver: no status window in blocking mode (Ctrl-C stops it).\n');
        end
        r.listen();        % owns this session until Ctrl-C
    else
        % Listener FIRST, window second: a GUI that fails to build must never cost
        % you the listener, which is the thing that actually arms ScanImage.
        r.listen_async();  % returns immediately; r.stop() to halt
        if gui
            try
                SIListenerMonitor(r);
            catch err
                fprintf(['[si] status window failed to open (%s); the listener is ' ...
                         'running -- use r.status() / r.stop().\n'], err.message);
            end
        end
    end
end

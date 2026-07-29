function r = start_si_listener(si_root)
%START_SI_LISTENER Run once on the ScanImage computer's MATLAB session.
%   Starts a persistent listener that primes ScanImage for each experiment the
%   DAQ master prepares: sets the save filename (matching the DAQ Saver stem),
%   enables logging + external trigger, enables the experiment's user function,
%   and arms acquisition. Leave it running all session; it re-primes on every
%   Prepare. Requires hSI and hSICtl in the base workspace (ScanImage running).
%
%   Usage (on the SI computer):
%       start_si_listener            % tiffs under D:\<date>\<mouse>\<epoch><expt>\
%       start_si_listener('E:')      % use a different local drive/base
%
%   Ctrl-C to stop. See also SIReceiver, Receiver, prime_info.

    if nargin < 1, si_root = ''; end

    here = fileparts(mfilename('fullpath'));   % holodaq/receivers
    addpath(genpath(fileparts(here)));         % put holodaq (HolochatInterface, ...) on path

    r = SIReceiver(si_root);
    r.listen();   % blocks
end

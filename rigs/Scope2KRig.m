function rig = Scope2KRig()
%SCOPE2KRIG Rig definition for Scope2K (formerly the FrankenScope).
%   Loaded via load_rig (see rigs/README.md). To adapt holodaq to another
%   microscope, copy rigs/ExampleRig.m — every field is documented there.

rig.name = 'Scope2K';

% ---- paths ---------------------------------------------------------------
% MATLAB paths default_setup adds (data drive + sibling code checkouts).
rig.paths.matlab_paths = {'K:\', genpath('C:\Users\holos\Documents\_code')};
rig.paths.data_root    = 'K://KKS//stim-data';   % Saver output root
rig.paths.si_root      = 'D:';                   % ScanImage tiff root (SI computer)
rig.paths.holo_request = '';                     % holoRequest.mat folder (filled from legacy K:\ files below)

% ---- DAQ -------------------------------------------------------------------
rig.daq.vendor = 'ni';
rig.daq.device = '';      % '' = auto-detect (first daqlist device)
rig.daq.rate   = 20000;   % samples/s

% ---- serial devices ----------------------------------------------------------
rig.serial.ell14 = struct('port', 'COM4', 'baud', 9600, ...
    'byte_order', 'big-endian', 'parity', 'none', ...
    'stop_bits', 1, 'data_bits', 8, 'terminator', 'CR/LF');   % HWP rotators
rig.serial.wheel = struct('port', 'COM3', 'baud', 115200, ...
    'terminator', 'CR/LF');                                   % Arduino running wheel

% ---- modules -----------------------------------------------------------------
% A module listed here exists on this rig; omit the field entirely on rigs
% that lack the hardware (scripts skip construction via rig_has).
rig.modules.si         = struct('trigger', 'port0/line0', 'frame', 'ai0');
% PsychToolbox computer trigger. port0/line17 is what Experiment.setup and every
% live non-voltage-imaging runner use. NOTE: the voltage-imaging runners under
% expts/Andrea/voltage-imaging/ instead use port0/line7 for the PTB trigger, and
% additionally bind port0/line2 and port0/line3 as PTB *inputs* -- the lines this
% file assigns to the SLM triggers below. Those runners build the rig inline and
% keep their own literals, so they are unaffected by this entry; resolve on-rig
% whether line7 is a second physical PTB line before migrating them (load_rig's
% duplicate-channel check cannot help, since only one value ever lands here).
rig.modules.ptb        = struct('trigger', 'port0/line17');
rig.modules.holo       = struct();   % HoloComputer: holochat only, no DAQ wiring
rig.modules.fpc_900    = struct('shutter', 'port0/line5', 'serial', 'ell14', ...
    'ell14_channel', 1, 'calibration', '', 'khz', 250);
rig.modules.fpc_1100   = struct('shutter', 'port0/line4', 'serial', 'ell14', ...
    'ell14_channel', 2, 'calibration', '', 'khz', 250);
rig.modules.slm_900    = struct('trigger', 'port0/line2', 'flip', 'ai1');
rig.modules.slm_1100   = struct('trigger', 'port0/line3', 'flip', 'ai2');
rig.modules.patch      = struct('output', 'ao0', 'input', 'ai7');
rig.modules.wheel      = struct('serial', 'wheel');
rig.modules.laser_gate = struct('output', 'ao1', 'max_voltage', 3.5);

% ---- opto (photostim) channels ---------------------------------------------
% THE declaration of this rig's opto channel identity: one entry per laser + SLM
% path. Both halves of an entry are load-bearing.
%   name       -> the params.pool field. 'red'/'blue' are exactly what the ~36
%                 existing experiment files already write (pool(ct).red /
%                 pool(ct).blue), so they run unedited and no alias is needed.
%   wavelength -> DERIVES params.holoinfo.hr<nm> and the saved stim_<nm> (see
%                 opto_channels), reproducing hr1100/hr900 and
%                 stim_1100/stim_900 exactly. Never hand-typed, so a rig-file
%                 typo cannot cross one laser's power command with another
%                 wavelength's calibration.
% ORDER IS THE WIRE ORDER: the sequence holoRequests are transferred in and the
% cell position of each firing order. 1100 first reproduces today's transfer
% order (FullExperiment.initialize sends hr1100 then hr900) and the holo
% listener's historical [1100 900] default, so an un-updated listener still
% agrees. Note this is deliberately NOT the module add order in
% Experiment.setup, which adds 900 first -- that order fixes DAQ channel
% registration and is a separate concern.
rig.opto = [ opto_channel('red',  1100, 'fpc_1100', 'slm_1100'), ...
             opto_channel('blue',  900, 'fpc_900',  'slm_900') ];

% ---- network -------------------------------------------------------------------
rig.network.holochat_server = 'http://136.152.58.120:8000';   % holochat broker
rig.network.remote_port     = 8765;                           % phone-control server (remote/)

% ---- legacy K:\ scaffolding ------------------------------------------------------
% The calibration LUT paths and the holoRequest folder still live in the old
% rig-machine files (K:\power_calibrations.m, K:\FrankenScopeRigFile.m).
% TODO(on-rig): inline those literals above, then delete this block.
if isfolder('K:\')
    addpath('K:\');
    if exist('power_calibrations', 'file')
        power_calibration = struct('calibration_900', '', 'calibration_1100', '');
        power_calibrations;   % legacy script; fills the power_calibration struct
        rig.modules.fpc_900.calibration  = power_calibration.calibration_900;
        rig.modules.fpc_1100.calibration = power_calibration.calibration_1100;
    end
    if exist('FrankenScopeRigFile', 'file')
        loc = FrankenScopeRigFile();
        if isfield(loc, 'HoloRequest')
            rig.paths.holo_request = loc.HoloRequest;
        end
    end
end
end

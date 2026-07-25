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

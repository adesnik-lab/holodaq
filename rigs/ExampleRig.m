function rig = ExampleRig()
%EXAMPLERIG Template rig definition — copy this file to define your own rig.
%
%   To adapt holodaq to your microscope:
%     1. Copy this file to rigs/<YourName>Rig.m and rename the function.
%     2. Fill in the fields below for your hardware. DELETE the entries for
%        hardware your rig does not have — experiment scripts check module
%        presence with rig_has(rig, '<module>') and skip what's missing.
%     3. Select your rig per machine: set the HOLODAQ_RIG environment
%        variable, or copy rigs/rig_config.m.example to rig_config.m
%        (gitignored) on your MATLAB path. If yours is the only rig file in
%        rigs/, it is picked automatically.
%
%   load_rig validates the struct (channel formats, duplicate channel
%   assignments, serial references) and fills the documented defaults.
%   See rigs/README.md and rigs/Scope2KRig.m for a complete working example.

rig.name = 'Example';   % REQUIRED — a short name for this rig

% ---- paths (all optional) --------------------------------------------------
% matlab_paths : folders default_setup adds to the MATLAB path (data drives,
%                sibling code checkouts). Use genpath(...) for recursive adds.
% data_root    : where Saver writes experiment .mat files
%                (default 'K://KKS//stim-data' when absent).
% si_root      : drive/base for ScanImage tiff logging on the SI computer
%                (default 'D:').
% holo_request : folder holding holoRequest.mat for holography experiments.
rig.paths.matlab_paths = {};
rig.paths.data_root    = 'C:\data';
rig.paths.si_root      = 'D:';
rig.paths.holo_request = '';

% ---- DAQ ---------------------------------------------------------------------
% vendor : MATLAB daq() vendor id ('ni', 'mcc', ...). Default 'ni'.
% device : DAQ device id, e.g. 'Dev1'. '' = auto-detect the first daqlist
%          device (fine when only one DAQ is installed). Default ''.
% rate   : sample rate in samples/s. REQUIRED if any module below declares a
%          DAQ channel.
rig.daq.vendor = 'ni';
rig.daq.device = '';
rig.daq.rate   = 20000;

% ---- serial devices (optional) --------------------------------------------------
% One entry per serial device; modules reference them by name (see below).
% Fields: port (required), baud (default 9600), byte_order, parity,
% stop_bits, data_bits, terminator (default 'CR/LF'). Opened by open_serial.
rig.serial.ell14 = struct('port', 'COM4', 'baud', 9600, ...
    'byte_order', 'big-endian', 'parity', 'none', ...
    'stop_bits', 1, 'data_bits', 8, 'terminator', 'CR/LF');

% ---- modules --------------------------------------------------------------------
% Each field declares one module that exists on this rig and its physical
% wiring. DELETE entries for hardware you don't have. DAQ channel strings:
%   digital  port<n>/line<n>     analog  ai<n> / ao<n>     counter  ctr<n>
% Channel-holding field names (validated): trigger, frame, shutter, flip,
% output, input, counter. A 'serial' field must name a rig.serial entry.
%
% Modules the stock experiment scripts / GUIs know about:
%   si         : ScanImage computer — trigger (digital out), frame (analog in)
%   ptb        : PsychToolbox visual-stimulus computer — trigger (digital out)
%   holo       : holography computer — no wiring (talks over holochat)
%   fpc_900    : fiber power control — shutter (digital out), serial (ELL14
%   fpc_1100     bus name), ell14_channel (rotator address on that bus),
%                calibration (path to power->angle LUT .mat), khz
%   slm_900    : SLM comm — trigger (digital out), flip (analog in)
%   slm_1100
%   patch      : patch clamp — output (analog out), input (analog in)
%   wheel      : running wheel — serial (rig.serial entry name)
%   laser_gate : laser gate — output (analog out). max_voltage (V, "on" level)
%                is read by PowerControllerCalibrated only; at trial time
%                LaserGate pins 3.5 V as a Constant (LaserGate.m:46), so
%                changing max_voltage here does not change the trial sweep.
rig.modules.si         = struct('trigger', 'port0/line0', 'frame', 'ai0');
rig.modules.ptb        = struct('trigger', 'port0/line17');
rig.modules.fpc_900    = struct('shutter', 'port0/line5', 'serial', 'ell14', ...
    'ell14_channel', 1, 'calibration', '', 'khz', 250);
rig.modules.laser_gate = struct('output', 'ao1', 'max_voltage', 3.5);

% ---- network (all optional) ---------------------------------------------------------
% holochat_server : REST broker coordinating the DAQ / SI / holo / PTB
%                   computers (default: the lab broker, see HolochatInterface).
% remote_port     : localhost port of the phone-control server (default 8765).
% remote_api      : full API base URL; '' derives http://127.0.0.1:<port>/api.
rig.network.holochat_server = 'http://example-broker:8000';
rig.network.remote_port     = 8765;
end

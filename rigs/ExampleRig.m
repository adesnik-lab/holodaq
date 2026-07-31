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
% expt_params  : where per-run experiment parameter .json/.mat files go
%                (default 'K:/KKS/expt-params'). On Scope2K this is a SIBLING of
%                data_root, not a child, so it is its own field.
% si_root      : drive/base for ScanImage tiff logging on the SI computer
%                (default 'D:').
% holo_request : folder holding holoRequest.mat for holography experiments.
% calib_dir    : SLM/CoC calibration folder on the HOLOGRAPHY computer. Both read
%                (find_latest_calib) and written (the alignSLMtoCam scripts), so
%                it must be one folder -- split them and a fresh calibration
%                lands where nothing loads it from.
% power_calib_dir : power->angle LUTs the AutoLaserPowerCalib_* scripts write and
%                rig.modules.fpc_*.calibration reads.
% slm_sdk      : SLM vendor SDK install folder on the holography computer, added
%                to the path by start_holo_listener. '' if already on the path.
%
% NOTE matlab_paths is MACHINE-scoped, not rig-scoped: it is the addpath list for
% whichever machine loads this file, so publish_rig_config never sends it to the
% satellites. Same for the network.remote_api that validate_rig derives.
rig.paths.matlab_paths = {};
rig.paths.data_root    = 'C:\data';
rig.paths.expt_params  = 'C:\data\expt-params';
rig.paths.si_root      = 'D:';
rig.paths.holo_request = '';
rig.paths.calib_dir    = 'C:\calibs';
rig.paths.power_calib_dir = 'C:\power-calibrations';
rig.paths.holo_scratch = '';   % holeburn .tif staging for the alignment flow
rig.paths.slm_sdk      = '';   % SLM vendor SDK install, if not on the path
rig.paths.slm_lut_dir  = '';   % base for a relative opto_channel slm_lut

% ---- holography computer settings --------------------------------------------
% Read by start_holo_listener on the holo box (via rig_remote_get, since that
% machine has no rig file of its own).
% cgh_method     : hologram algorithm id (2 = GSS)
% use_gpu        : compile holograms on the GPU
% slm_timeout_ms : SLM trigger timeout
rig.holo.cgh_method     = 2;
rig.holo.use_gpu        = true;
rig.holo.slm_timeout_ms = 1700;

% ---- PsychToolbox / PsychoPy computer settings --------------------------------
% Read from PYTHON on that machine (psychopy_defaults), so paths are in its OS's
% form -- a tty on Linux, 'COM<n>' on Windows.
% trigger_port/_baud/_timeout : serial line the box reads the DAQ trigger on
% monitor                     : name of a calibrated monitor in PsychoPy's store
% observe_monitor             : monitor for the small mirror window
% stim_screen / observe_screen: screen indices
%
% Its own group, NOT fields on rig.modules.ptb: rig_hardware opens every
% rig.serial entry that a module's 'serial' field references, so naming this tty
% there would make the DAQ try to open the PTB box's serial port.
rig.ptb.trigger_port    = '/dev/ttyUSB0';
rig.ptb.trigger_baud    = 9600;
rig.ptb.trigger_timeout = 15;
rig.ptb.monitor         = 'experiment_calibrated';
rig.ptb.observe_monitor = 'observation';
rig.ptb.stim_screen     = 1;
rig.ptb.observe_screen  = 0;

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
% Bus the power-calibration scripts drive. Not opened by rig_hardware unless a
% module's 'serial' field names it, so an entry here is inert until something asks.
rig.serial.sutter = struct('port', 'COM3', 'baud', 9600);   % Sutter MP285
rig.serial.hwp   = struct('port', 'COM5', 'baud', 9600, ...
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
%   fpc_<tag>  : fiber power control — shutter (digital out), serial (ELL14
%                bus name), ell14_channel (rotator address on that bus),
%                calibration (path to power->angle LUT .mat), khz. The <tag> is
%                free: a module is bound to an opto channel by rig.opto below,
%                not by its name.
%   slm_<tag>  : SLM comm — trigger (digital out), flip (analog in)
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
% The single opto path this template declares. Named for the wavelength here only
% by habit -- rig.opto below is what binds them to a channel, so any tag works.
rig.modules.fpc_1040   = struct('shutter', 'port0/line6', 'serial', 'ell14', ...
    'ell14_channel', 2, 'calibration', '', 'khz', 250);   % distinct rotator address
rig.modules.slm_1040   = struct('trigger', 'port0/line8', 'flip', 'ai3');

% ---- opto (photostim) channels (optional) ----------------------------------
% One entry per laser + SLM path. DELETE the field entirely on a rig with no
% photostim lasers -- opto_channels then returns an empty table and vis-only
% experiments run normally.
%
% THE COMMON CASE IS ONE CHANNEL. No ceremony, no special case:
rig.opto = opto_channel('act', 1040, 'fpc_1040', 'slm_1040');
%
% Two channels. The ORDER is the wire order: the sequence holoRequests are
% transferred in, and the cell position of each firing order.
%   rig.opto = [ opto_channel('red',  1100, 'fpc_1100', 'slm_1100'), ...
%                opto_channel('blue',  900, 'fpc_900',  'slm_900') ];
%
% Three channels at other wavelengths, named for what they do rather than for a
% colour:
%   rig.opto = [ opto_channel('act',  920, 'fpc_920',  'slm_920'), ...
%                opto_channel('sup', 1040, 'fpc_1040', 'slm_1040'), ...
%                opto_channel('aux', 1064, 'fpc_1064', 'slm_1064') ];
%
% One laser split across two SLMs (same wavelength). Legal, and the reason the
% pool key is the NAME rather than the wavelength -- but each arm must declare
% its own board, because the holography computer would otherwise resolve the
% board from the wavelength alone and hand both arms the same one:
%   rig.opto = [ opto_channel('arm1', 1040, 'fpc_a', 'slm_a', 'slm_board', 1), ...
%                opto_channel('arm2', 1040, 'fpc_b', 'slm_b', 'slm_board', 2) ];
%
% Each entry's NAME is the params.pool field (pool(i).<name>). Each entry's
% WAVELENGTH derives the params.holoinfo field (hr<nm>) and the saved field
% (stim_<nm>) -- see opto_channels, which also validates the whole table at
% load_rig time. Neither is ever typed twice, so no rig-file entry can bind one
% laser's power command to another wavelength's calibration.

% ---- network (all optional) ---------------------------------------------------------
% holochat_server : REST broker coordinating the DAQ / SI / holo / PTB
%                   computers (default: the lab broker, see HolochatInterface).
% remote_port     : localhost port of the phone-control server (default 8765).
% remote_api      : full API base URL; '' derives http://127.0.0.1:<port>/api.
rig.network.holochat_server = 'http://example-broker:8000';
rig.network.remote_port     = 8765;
end

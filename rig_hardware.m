function hw = rig_hardware()
%RIG_HARDWARE Load this machine's rig and open the hardware it declares.
%   hw = RIG_HARDWARE() returns a struct with
%     hw.rig                the loaded, validated rig struct (see load_rig)
%     hw.dq                 the daq object, at rig.daq.rate
%     hw.serial             struct of OPEN serialports, keyed by rig.serial name
%     hw.sp                 alias for hw.serial.ell14 -- FIELD ABSENT if no such bus
%     hw.arduino_obj        alias for hw.serial.wheel -- FIELD ABSENT if no such bus
%     hw.power_calibration  back-compat: .calibration_900 / .calibration_1100
%
%   This is the body of the default_setup script, as a function, so callers that
%   cannot rely on script-into-workspace injection (classdef methods -- see
%   Experiment/setup in holoexpt) get the same preamble from the same source.
%   default_setup now just unpacks what this returns.
%
%   Which buses are opened: every rig.serial entry that a declared
%   rig.modules.<m>.serial references, plus the conventional 'ell14' and 'wheel'
%   entries when present (so default_setup's sp / arduino_obj keep their exact
%   old contract). Entries nothing references are left closed.
%
%   See also DEFAULT_SETUP, LOAD_RIG, OPEN_SERIAL, RIG_HAS.

% Per-rig configuration: everything machine-specific (channels, COM ports,
% rates, paths) lives in the rig file (rigs/<Name>Rig.m). See rigs/README.md.
addpath(fullfile(fileparts(mfilename('fullpath')), 'rigs'));

hw = struct();
hw.rig = load_rig();
rig = hw.rig;

warning('off', 'MATLAB:structOnObject');

% Rig-specific MATLAB paths (data drives, sibling code checkouts).
cellfun(@addpath, rig.paths.matlab_paths(~cellfun(@isempty, rig.paths.matlab_paths)));

fprintf('Loading defaults... ')
pause(0.1)
fprintf('OK.\n')

fprintf('Making MATLAB NIDAQ object... ')
dq = daq(rig.daq.vendor);
dq.Rate = rig.daq.rate;
hw.dq = dq;
pause(0.1)
fprintf('OK.\n')

% ---- serial buses ---------------------------------------------------------
hw.serial = struct();
for name = serial_buses_to_open(rig)
    switch name{1}
        case 'ell14'
            fprintf('Making serialport object... ')
        case 'wheel'
            fprintf('Connecting running wheel...')
        otherwise
            fprintf('Opening serial ''%s''... ', name{1})
    end
    hw.serial.(name{1}) = open_serial(rig.serial.(name{1}));
    pause(0.1)
    fprintf('OK.\n')
end

% Back-compat aliases for the names default_setup has always exported. Left
% ABSENT (not []) when the rig has no such bus, so exist('sp','var') keeps its
% old value for the runners that call default_setup.
if isfield(hw.serial, 'ell14'), hw.sp          = hw.serial.ell14; end
if isfield(hw.serial, 'wheel'), hw.arduino_obj = hw.serial.wheel; end

% Back-compat: old scripts read power_calibration.calibration_900/_1100 (the
% struct the legacy K:\ power_calibrations script defined). Rebuild it from the
% rig file so they keep working.
hw.power_calibration = struct();
if rig_has(rig, 'fpc_900')
    hw.power_calibration.calibration_900 = rig.modules.fpc_900.calibration;
end
if rig_has(rig, 'fpc_1100')
    hw.power_calibration.calibration_1100 = rig.modules.fpc_1100.calibration;
end
end

% -------------------------------------------------------------------------
function names = serial_buses_to_open(rig)
%SERIAL_BUSES_TO_OPEN Row cell of rig.serial names to open, in a stable order.
%   'ell14' then 'wheel' first, so the progress lines and the COM-port open
%   order match what default_setup has always done; then any other bus a
%   declared module references. load_rig has already checked that every module's
%   'serial' names a real rig.serial entry.
    names = {};
    for conventional = {'ell14', 'wheel'}
        if isfield(rig.serial, conventional{1})
            names{end+1} = conventional{1}; %#ok<AGROW>
        end
    end
    for m = fieldnames(rig.modules)'
        cfg = rig.modules.(m{1});
        if isfield(cfg, 'serial') && ~any(strcmp(cfg.serial, names))
            names{end+1} = char(cfg.serial); %#ok<AGROW>
        end
    end
end

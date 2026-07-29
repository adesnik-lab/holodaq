% Per-rig configuration: everything machine-specific (channels, COM ports,
% rates, paths) lives in the rig file (rigs/<Name>Rig.m). See rigs/README.md.
addpath(fullfile(fileparts(mfilename('fullpath')), 'rigs'));
rig = load_rig();

warning('off', 'MATLAB:structOnObject');

% Rig-specific MATLAB paths (data drives, sibling code checkouts).
cellfun(@addpath, rig.paths.matlab_paths(~cellfun(@isempty, rig.paths.matlab_paths)));

fprintf('Loading defaults... ')
pause(0.1)
fprintf('OK.\n')

fprintf('Making MATLAB NIDAQ object... ')
dq = daq(rig.daq.vendor);
dq.Rate = rig.daq.rate;
pause(0.1)
fprintf('OK.\n')

if isfield(rig.serial, 'ell14')
    fprintf('Making serialport object... ')
    sp = open_serial(rig.serial.ell14);
    pause(0.1)
    fprintf('OK.\n')
end

if isfield(rig.serial, 'wheel')
    fprintf('Connecting running wheel...')
    arduino_obj = open_serial(rig.serial.wheel);
    pause(0.1)
    fprintf('OK.\n')
end

% Back-compat: old scripts read power_calibration.calibration_900/_1100 (the
% struct the legacy K:\ power_calibrations script defined). Rebuild it from
% the rig file so they keep working.
power_calibration = struct();
if rig_has(rig, 'fpc_900')
    power_calibration.calibration_900 = rig.modules.fpc_900.calibration;
end
if rig_has(rig, 'fpc_1100')
    power_calibration.calibration_1100 = rig.modules.fpc_1100.calibration;
end

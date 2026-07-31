% Per-rig configuration: everything machine-specific (channels, COM ports,
% rates, paths) lives in the rig file (rigs/<Name>Rig.m). See rigs/README.md.
%
% This script is the workspace-injecting front end for rig_hardware(): it leaves
% rig / dq / sp / arduino_obj / power_calibration in the CALLER's workspace,
% exactly as it always has, for the experiment runners that expect that.
% Callers that cannot rely on that injection -- classdef methods, e.g.
% holoexpt's Experiment/setup -- call rig_hardware() directly instead.
hw = rig_hardware();

rig = hw.rig;
dq  = hw.dq;
% sp / arduino_obj stay UNDEFINED (not []) when the rig declares no such bus --
% what this script has always done. A bare assignment would flip
% exist('sp','var') from false to true for existing callers.
if isfield(hw, 'sp')
    sp = hw.sp;
end
if isfield(hw, 'arduino_obj')
    arduino_obj = hw.arduino_obj;
end
power_calibration = hw.power_calibration;

% Do not leave a second reference to the DAQ object and the serialports lying
% around: a runner doing `clear sp` must actually release COM4.
clear hw

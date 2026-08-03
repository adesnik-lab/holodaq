function [laser, wiring] = power_control(dq, cfg, module_name, label, serial_port)
%POWER_CONTROL Build the LaserPowerControl an fpc module declares.
%   [laser, wiring] = POWER_CONTROL(dq, rig.modules.fpc_x, 'fpc_x', label, sp)
%   returns the constructed power-control module and a one-line description of
%   the wiring it resolved to (for the startup audit).
%
%   `serial_port` is the ALREADY-OPEN serialport for the bus this module names,
%   and is only used by kind 'ell14'. Pass [] for a modulator rig -- rig_hardware
%   opens no bus for one, because nothing references one.
%
%   This is the single place that decides which objects a power path is made of.
%   It exists because Experiment.setup used to hardcode
%       LaserPowerControl(Output(DAQOutput(shutter)), ELL14(SerialInterface(..)), lut)
%   which is one specific rig's hardware written into the runtime: a scope that
%   sets power with a modulator could not be described at all, no matter what its
%   rig file said. The `control` slot of LaserPowerControl was ALREADY
%   polymorphic -- holography2k/alignment/alignCodeDAQ2K.m and the voltage-imaging
%   runner both pass a LaserModulator there instead of an ELL14 -- so the missing
%   piece was never a class, only a way for the rig file to ask for one.
%
%   See also: power_control_spec, LaserPowerControl, LaserModulator, ELL14

    if nargin < 4 || isempty(label), label = module_name; end
    if nargin < 5, serial_port = []; end

    spec = power_control_spec(cfg, module_name, label);

    % The shutter, when there is one. Same construction for both kinds: an
    % Output wrapping a digital DAQ line.
    shutter = [];
    if ~isempty(spec.shutter)
        shutter = Output(DAQOutput(dq, spec.shutter), sprintf('Shutter %s', label));
    end

    switch spec.kind
        case 'ell14'
            assert(~isempty(serial_port), 'power_control:noSerial', ...
                ['rig.modules.%s is kind ''ell14'', so it needs the open ' ...
                 'serialport for bus ''%s''.\nNone was passed. rig_hardware opens ' ...
                 'every rig.serial entry a declared module\nreferences, so this ' ...
                 'usually means the module names a bus the rig does not define.'], ...
                module_name, spec.serial);

            control = ELL14(SerialInterface(serial_port), spec.ell14_channel, ...
                            sprintf('Power %s', label));
            laser = LaserPowerControl(shutter, control, spec.calibration);

            wiring = sprintf('ell14: shutter %s, rotator %s on ''%s'', LUT %s', ...
                spec.shutter, local_show(spec.ell14_channel), spec.serial, ...
                local_lut(spec.calibration));

        case 'eom'
            % LaserModulator takes the DAQOutput directly (it is a Component, not
            % an Output wrapper) -- same as the two existing call sites.
            control = LaserModulator(DAQOutput(dq, spec.output), ...
                                     sprintf('Power %s', label));
            laser = LaserPowerControl(shutter, control, spec.calibration, ...
                'GateMode', spec.gate_mode, 'RestValue', spec.rest);

            if strcmp(spec.gate_mode, 'waveform')
                gate = sprintf('gated by the waveform itself (rest %g V)', spec.rest);
            else
                gate = sprintf('gated by shutter %s (rest %g V)', spec.shutter, spec.rest);
            end
            wiring = sprintf('eom: output %s, %s, LUT %s', ...
                spec.output, gate, local_lut(spec.calibration));

        otherwise
            % power_control_spec already refused anything else; this is only
            % reachable if the two ever drift apart.
            error('power_control:badKind', ...
                'Unhandled power-control kind ''%s'' for rig.modules.%s.', ...
                spec.kind, module_name);
    end
end

% -------------------------------------------------------------------------
function s = local_lut(p)
    if isempty(p)
        s = '<none>';
    else
        s = char(p);
    end
end

function s = local_show(v)
    if ischar(v) || isstring(v)
        s = char(v);
    else
        s = mat2str(v);
    end
end

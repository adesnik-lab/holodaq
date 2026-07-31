function spec = power_control_spec(cfg, module_name, channel_name)
%POWER_CONTROL_SPEC Validate and normalise an fpc module's power-control wiring.
%   spec = POWER_CONTROL_SPEC(rig.modules.fpc_x, 'fpc_x', 'act') checks that the
%   module declares a coherent power path and returns it with defaults filled in.
%
%   An optogenetic channel needs two things: a way to SET the power, and a way to
%   make sure the laser is dark the rest of the time. Rigs do that with different
%   hardware, so the module declares a KIND:
%
%     kind = 'ell14'  (DEFAULT -- what every rig file before this field meant)
%         A half-wave plate on an Elliptec rotator sets the power, and a digital
%         shutter gates it.
%           shutter        REQUIRED  digital line, e.g. 'port0/line5'
%           serial         REQUIRED  name of the rig.serial bus the rotator is on
%           ell14_channel  REQUIRED  rotator address on that bus
%           calibration    optional  power->angle LUT .mat
%           khz            optional  read by the power GUIs only
%
%     kind = 'eom'
%         An electro-optic modulator (or Pockels cell, or AOM) on an ANALOG line
%         sets the power. There is usually no shutter at all: the modulator is
%         driven to `rest` whenever the laser must be dark, so the same line both
%         sets and gates.
%           output         REQUIRED  analog line, e.g. 'ao3'
%           calibration    optional  power->volts LUT .mat
%           rest           optional  volts written when dark (default 0)
%           shutter        optional  digital line, if the rig also has one
%
%   WHY THE KIND IS EXPLICIT rather than inferred from which fields are present:
%   inference would make a typo'd 'shutter' silently reclassify the channel, and
%   the two kinds gate the laser by completely different mechanisms. Getting that
%   wrong does not fail loudly -- it delivers light at the wrong time.
%
%   Returned fields (always present, so callers need no isfield checks):
%     .kind         'ell14' | 'eom'
%     .shutter      channel string, or '' when there is none
%     .gate_mode    'shutter' | 'waveform'   how the laser is kept dark
%     .calibration  path, or ''
%     .serial / .ell14_channel        (ell14 only; '' / [] otherwise)
%     .output / .rest                 (eom only; '' / [] otherwise)
%     .khz          numeric, or []
%
%   Called at LOAD time by opto_channels (so a bad declaration is refused before
%   any hardware opens) and again at BUILD time by power_control, which is the
%   only place that turns this into objects.
%
%   See also: power_control, opto_channels, LaserPowerControl, ExampleRig

    if nargin < 2 || isempty(module_name), module_name = '<module>'; end
    if nargin < 3 || isempty(channel_name), channel_name = '<channel>'; end

    where = sprintf('rig.modules.%s (opto channel ''%s'')', module_name, channel_name);

    assert(isstruct(cfg) && isscalar(cfg), 'power_control_spec:badModule', ...
        '%s must be a scalar struct.', where);

    kind = 'ell14';
    if isfield(cfg, 'kind') && ~isempty(cfg.kind)
        kind = lower(strtrim(char(cfg.kind)));
    end

    spec = struct('kind', kind, 'shutter', '', 'gate_mode', 'shutter', ...
                  'calibration', '', 'serial', '', 'ell14_channel', [], ...
                  'output', '', 'rest', [], 'khz', []);

    if isfield(cfg, 'calibration') && ~isempty(cfg.calibration)
        spec.calibration = char(cfg.calibration);
    end
    if isfield(cfg, 'khz') && ~isempty(cfg.khz)
        spec.khz = cfg.khz;
    end

    switch kind
        case 'ell14'
            missing = setdiff({'shutter', 'serial', 'ell14_channel'}, ...
                              reshape(fieldnames(cfg), 1, []));
            assert(isempty(missing), 'power_control_spec:ell14Wiring', ...
                ['%s declares kind ''ell14'' but is missing: %s.\n' ...
                 'An Elliptec power path needs a ''shutter'' DAQ line, a ' ...
                 '''serial'' (the rig.serial\nbus name) and an ''ell14_channel'' ' ...
                 '(the rotator address on that bus).\nIf this rig sets power with ' ...
                 'a modulator on an analog line instead, declare\nkind = ''eom'' ' ...
                 'and an ''output'' -- see rigs/ExampleRig.m.'], ...
                where, strjoin(missing, ', '));

            spec.shutter       = strtrim(char(cfg.shutter));
            spec.serial        = char(cfg.serial);
            spec.ell14_channel = cfg.ell14_channel;
            spec.gate_mode     = 'shutter';

            assert(~isempty(spec.shutter), 'power_control_spec:ell14Wiring', ...
                '%s has an empty ''shutter''.', where);

        case 'eom'
            assert(isfield(cfg, 'output') && ~isempty(cfg.output), ...
                'power_control_spec:eomWiring', ...
                ['%s declares kind ''eom'' but no ''output''.\n' ...
                 'A modulator power path needs the ANALOG line that drives it, ' ...
                 'e.g.\n  rig.modules.%s = struct(''kind'', ''eom'', ''output'', ' ...
                 '''ao3'', ''rest'', -0.375);'], where, module_name);

            spec.output = strtrim(char(cfg.output));
            assert(~isempty(regexp(spec.output, '^ao[0-9]+$', 'once')), ...
                'power_control_spec:eomAnalog', ...
                ['%s: ''output'' = ''%s'' is not an analog output line.\n' ...
                 'A modulator is driven with a voltage waveform, so this must be ' ...
                 'ao<n>. A digital\nline can only be on or off, which cannot set ' ...
                 'a power level.'], where, spec.output);

            spec.rest = 0;
            if isfield(cfg, 'rest') && ~isempty(cfg.rest)
                assert(isnumeric(cfg.rest) && isscalar(cfg.rest) && isfinite(cfg.rest), ...
                    'power_control_spec:eomRest', ...
                    '%s: ''rest'' must be a finite scalar voltage.', where);
                spec.rest = double(cfg.rest);
            end

            % A shutter is allowed but not required here. When absent the
            % modulator waveform itself must return to `rest` outside the pulse
            % windows -- that is what gate_mode says, and what LaserPowerControl
            % acts on.
            if isfield(cfg, 'shutter') && ~isempty(cfg.shutter)
                spec.shutter   = strtrim(char(cfg.shutter));
                spec.gate_mode = 'shutter';
            else
                spec.gate_mode = 'waveform';
            end

        otherwise
            error('power_control_spec:badKind', ...
                ['%s declares kind ''%s'', which is not a power-control kind.\n' ...
                 'Known kinds: ''ell14'' (half-wave plate + shutter, the default) ' ...
                 'and ''eom''\n(modulator on an analog line). See ' ...
                 'rigs/ExampleRig.m.'], where, kind);
    end

    % A modulator with no shutter is the ONLY configuration where the power
    % command also carries the timing. Say so once, here, so the invariant lives
    % in one place rather than being re-derived by each consumer.
    if strcmp(spec.gate_mode, 'waveform') && isempty(spec.calibration)
        warning('power_control_spec:noCalibration', ...
            ['%s sets power with a modulator and has NO calibration LUT.\n' ...
             'Without one there is no power->volts mapping, so the modulator ' ...
             'stays at rest\n(%g V) and the channel delivers NO light. Point ' ...
             '.calibration at a LUT .mat.'], where, spec.rest);
    end
end

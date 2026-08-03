% classdef LaserPowerControl < Module
%     properties
%         shutter
%         control
% 
%         pwr_fun
%         pwr_request
% 
%         shutter_params
%         % min_deg
%         % max_deg
%         min_pwr
%         max_pwr
%     end
% 
%     methods
%         function obj = LaserPowerControl(shutter, control, path_to_lut)
%             if nargin < 3 || isempty(path_to_lut)
%                 calib = [];
%             else
%                 calib = importdata(path_to_lut);
%             end
% 
%             % if nargin < 4 || isempty(current_khz)
%             %     current_khz = calib.khz;
%             %     fprintf('Assuming calibration khz (%dkHz)\n', calib.khz)
%             % end
% 
%             if ~isempty(calib)
%                 obj.get_pwr_fun(calib);
%             end
%             obj.shutter = shutter;
%             obj.control = control;
%             obj.pwr_request = obj.min_pwr;
%         end
% 
%         function get_pwr_fun(obj, calib)
%             %scale = current_khz/calib.khz;
%             % get unique only
%             [~, u_idx] = unique(calib.powers);
%             obj.pwr_fun = @(x) interp1(calib.powers(u_idx), calib.degrees(u_idx), x);
%             % when generating this, maybe set some things..
%             % obj.max_deg = calib.degrees(end);
%             % obj.min_deg = calib.degrees(1);
%             obj.max_pwr = calib.max_power;
%             obj.min_pwr = calib.min_power;
%         end
% 
%         % function control = pwr2con(obj, pwr_request)
%         %     control = obj.pwr_fun(pwr_request);
%         % end
% 
%         function open(obj)
%             sweep = zeros(1, obj.shutter.interface.n_outputs);
%             sweep(obj.shutter.interface.channel_idx) = 1;
%             obj.shutter.interface.io.write(sweep);
%         end 
% 
%         function close_all(obj)
%             % this is kinda meh rn, because it closes everything, but
%             % that's fine
%             sweep = zeros(1, numel(obj.shutter.interface.io.Channels));
%             sweep(obj.shutter.interface.channel_idx) = 0;
%             obj.shutter.interface.io.write(sweep); % ew
%         end
% 
%         function zero(obj)
%             obj.close_all()
%             obj.control.set(obj.pwr_fun(obj.min_pwr));
%             % obj.hwp.moveto(obj.min_deg)
%         end
% 
%         function set(obj, s)
%             % use the stiminfo to generate EVERYTHING you might need
%             % first let's unpack the stim info
%             % power control
%             % convert from power to power per cell...   
%             if ~isempty(s.sequence)
%                 de = s.sequence.average_de;
%             else
%                 de = 1;
%             end
% 
%             obj.set_power(s.power); % this is precalculated now
% 
%             % ok... now we need to set the shutter, but it might be weird?
%             % (idk)
%             %timing now..a
%             if s.power > 0 % only set this if there's power...
%                 obj.set_shutter(s.pulse_start', s.pulse_duration');
%             end
%         end
% 
%         function set_power(obj, pwr)
%             if any(pwr < obj.min_pwr) % lets us put in a vector
%                 disp('Outside of range, cannot use this power'); 
%                 pwr = obj.min_pwr;
%             end
%             obj.pwr_request = pwr;
%         end
% 
% 
%         function set_shutter(obj, starts, durations)
%             % ensure column
%             if size(starts, 2) ~= 1
%                 error('not a col');
%             end
%             obj.shutter.set([starts, durations])
%         end
% 
%         function set_shutter_old(obj, duration, on_time, frequency, delay)
%             if nargin < 5 || isempty(delay)
%                 delay = 0;
%             end
%             obj.shutter_params.duration = duration; % how long the shutter is open for
%             obj.shutter_params.on_time = on_time; % total on time...
%             obj.shutter_params.frequency = frequency;
%             obj.shutter_params.delay = delay;
% 
%             n_pulses = round(max(1, on_time/1000 * frequency));
%             if ~isempty(n_pulses)
%                 cycle = (1/frequency) * 1000;
%                 obj.shutter.set(cat(2, [delay+1:cycle:delay+on_time]', duration * ones(n_pulses, 1)));
%                 obj.shutter_params = [];
%             end
%         end
% 
%         function power(obj, pwr)
%             obj.control.set(obj.pwr_fun(pwr));
%             % obj.hwp.moveto(obj.pwr2deg(pwr_request));
%         end
% 
%         function prepare(obj)
%             %prepare hwp if power set
%             % if isempty(obj.control.interface.pulse.sweep)
%                 if ~isempty(obj.pwr_fun)
%                     val = obj.pwr_fun(obj.pwr_request);
%                     if isnan(val)
%                         disp('power out of range')
%                         return
%                     end
%                     obj.control.set(obj.pwr_fun(obj.pwr_request));
%                 end
%             % end
% 
%             % % prepare shutter if shutter set
%             % duration = obj.shutter_params.duration; % ms
%             % on_time = obj.shutter_params.on_time; %ms
%             % frequency = obj.shutter_params.frequency;
%             % delay = obj.shutter_params.delay;
%             % n_pulses = round(max(1, on_time/1000 * frequency));
%             % if ~isempty(n_pulses)
%             %     cycle = (1/frequency) * 1000;
%             %     obj.shutter.set(cat(2, [delay+1:cycle:delay+on_time]', duration * ones(n_pulses, 1), ones(n_pulses, 1)));
%             %     obj.shutter_params = [];
%             %     % obj.close_all();
%             % end
%         end
%     end
% end

classdef LaserPowerControl < Module
    %LASERPOWERCONTROL One optogenetic channel's power command and its gating.
    %   The `control` slot is polymorphic and always has been: an ELL14 (half-wave
    %   plate on a rotator) or a LaserModulator (EOM/Pockels/AOM on an analog
    %   line) both satisfy it, because both answer set(x). What differs is HOW THE
    %   LASER IS KEPT DARK between pulses, and that is what gate_mode names:
    %
    %     'shutter'  (default) a digital shutter line opens around the pulse
    %                envelope, and the control holds a single scalar for the whole
    %                trial. Every rig before this property behaved this way.
    %     'waveform' there is no shutter, so the power command ITSELF carries the
    %                timing: the modulator sits at rest_value and rises to the
    %                commanded level only inside the pulse windows.
    %
    %   The distinction is safety-critical, which is why it is an explicit
    %   property rather than something inferred from whether shutter is empty. A
    %   modulator with no shutter, driven with a scalar the way the ELL14 path
    %   does, would sit at full power for the ENTIRE trial -- the laser never
    %   turns off. Rigs declare the kind in their rig file; power_control_spec
    %   turns it into gate_mode.
    properties
        shutter
        control

        pwr_fun
        pwr_request

        shutter_params
        % min_deg
        % max_deg
        min_pwr
        max_pwr

        % How the laser is kept dark: 'shutter' or 'waveform'. See above.
        gate_mode = 'shutter'
        % Volts the modulator rests at when dark. gate_mode 'waveform' only.
        rest_value = 0
        % This trial's pulse windows, stashed by set() and consumed by prepare().
        % Needed because prepare() is what writes the sweep, but only set()
        % receives the StimInfo that says when the pulses are.
        stim_starts = []
        stim_durations = []
    end

    methods
        function obj = LaserPowerControl(shutter, control, path_to_lut, varargin)
            % LaserPowerControl(shutter, control, lut)
            % LaserPowerControl(shutter, control, lut, 'GateMode','waveform', ...
            %                   'RestValue', -0.375)
            %
            % `shutter` may be [] when the rig has none (see gate_mode above).
            %
            % The options are NAME-VALUE deliberately, not a 4th positional. Two
            % legacy call sites (holography2k/alignment/alignCodeDAQ2K.m and the
            % voltage-imaging blob runner) still pass a 4th positional current_khz
            % that this 3-argument constructor has not accepted for some time, so
            % they already error. A positional addition here would make those
            % calls start "working" with 1250 silently reinterpreted as a resting
            % VOLTAGE on a laser modulator. Name-value keeps them failing loudly.
            if nargin < 3 || isempty(path_to_lut)
                calib = [];
            else
                calib = importdata(path_to_lut);
            end

            p = inputParser;
            p.FunctionName = 'LaserPowerControl';
            p.addParameter('GateMode', 'shutter');
            p.addParameter('RestValue', 0);
            p.parse(varargin{:});

            obj.gate_mode = lower(strtrim(char(p.Results.GateMode)));
            assert(ismember(obj.gate_mode, {'shutter', 'waveform'}), ...
                'LaserPowerControl:badGateMode', ...
                'GateMode must be ''shutter'' or ''waveform'', got ''%s''.', obj.gate_mode);
            obj.rest_value = double(p.Results.RestValue);

            assert(~(strcmp(obj.gate_mode, 'shutter') && isempty(shutter)), ...
                'LaserPowerControl:noShutter', ...
                ['GateMode ''shutter'' needs a shutter Output, but none was ' ...
                 'given.\nA channel with no shutter must use GateMode ' ...
                 '''waveform'', so the power command\nitself returns the laser to ' ...
                 'rest between pulses -- otherwise nothing ever turns it off.']);

            if ~isempty(calib)
                obj.get_pwr_fun(calib);
            end
            obj.shutter = shutter;
            obj.control = control;
            obj.pwr_request = obj.min_pwr;
        end

        function get_pwr_fun(obj, calib)
            %scale = current_khz/calib.khz;
            % get unique only
            [~, u_idx] = unique(calib.powers);
            % The command column is 'degrees' for a rotator and 'volts' for a
            % modulator. Same interpolation, different units -- accept either
            % name so an EOM LUT does not have to store volts in a field called
            % 'degrees'. 'volts' wins when both are present.
            if isfield(calib, 'volts')
                command = calib.volts;
            else
                assert(isfield(calib, 'degrees'), 'LaserPowerControl:badCalib', ...
                    ['Power calibration has neither a ''volts'' nor a ''degrees'' ' ...
                     'column, so there is\nno power->command mapping in it. ' ...
                     'Fields present: %s'], ...
                    strjoin(reshape(fieldnames(calib), 1, []), ', '));
                command = calib.degrees;
            end
            obj.pwr_fun = @(x) interp1(calib.powers(u_idx), command(u_idx), x);
            % when generating this, maybe set some things..
            % obj.max_deg = calib.degrees(end);
            % obj.min_deg = calib.degrees(1);
            obj.max_pwr = calib.max_power;
            obj.min_pwr = calib.min_power;
        end
        
        % function control = pwr2con(obj, pwr_request)
        %     control = obj.pwr_fun(pwr_request);
        % end

        function tf = has_shutter(obj)
            tf = ~isempty(obj.shutter);
        end

        function open(obj)
            if ~obj.has_shutter(), return; end
            sweep = zeros(1, obj.shutter.interface.n_outputs);
            sweep(obj.shutter.interface.channel_idx) = 1;
            obj.shutter.interface.io.write(sweep);
        end

        function close_all(obj)
            % this is kinda meh rn, because it closes everything, but
            % that's fine
            if ~obj.has_shutter(), return; end
            sweep = zeros(1, numel(obj.shutter.interface.io.Channels));
            sweep(obj.shutter.interface.channel_idx) = 0;
            obj.shutter.interface.io.write(sweep); % ew
        end

        function zero(obj)
            % Command the channel dark. With a shutter that means closing it; on
            % a waveform-gated channel the shutter is a no-op and the resting
            % voltage IS the off state, so drive the control there directly
            % rather than through pwr_fun (which maps powers, not rest levels,
            % and is empty when the rig has no LUT).
            obj.close_all()
            if strcmp(obj.gate_mode, 'waveform')
                obj.control.set(obj.rest_value);
                return
            end
            obj.control.set(obj.pwr_fun(obj.min_pwr));
            % obj.hwp.moveto(obj.min_deg)
        end

        function set(obj, s)
            % use the stiminfo to generate EVERYTHING you might need
            % first let's unpack the stim info
            % power control
            % convert from power to power per cell...   
            if ~isempty(s.sequence)
                de = s.sequence.average_de;
            else
                de = 1;
            end
            
            obj.set_power(s.power); % this is precalculated now

            % Record THIS trial's pulse windows unconditionally, and clear them
            % when the channel is dark. prepare() builds the waveform from these,
            % and it runs once per trial -- so a stale window left over from the
            % previous trial would fire the laser on a trial commanded to zero.
            if s.power > 0
                obj.stim_starts    = s.pulse_start(:);
                obj.stim_durations = s.pulse_duration(:);
            else
                obj.stim_starts    = [];
                obj.stim_durations = [];
            end

            % ok... now we need to set the shutter, but it might be weird?
            % (idk)
            %timing now..a
            % if s.power > 0 % only set this if there's power...
            %     obj.set_shutter(s.pulse_start', s.pulse_duration');
            % end
            %
            % Shutter only. A waveform-gated channel has no shutter to open, and
            % must not borrow these margins either: they exist because a
            % mechanical shutter needs time to travel, whereas a modulator gates
            % at the sample. Widening its pulses by 50 ms each side would deliver
            % 100 ms of unrequested light per stim.
            if s.power > 0 && obj.has_shutter() && strcmp(obj.gate_mode, 'shutter')
                shutter_margin_pre  = 0.05;
                shutter_margin_post = 0.05;

                shutter_start = min(s.pulse_start) - shutter_margin_pre;
                shutter_end   = max(s.pulse_start + s.pulse_duration) + shutter_margin_post;

                shutter_start = max(shutter_start, 0);
                shutter_duration = shutter_end - shutter_start;

                obj.set_shutter(shutter_start(:), shutter_duration(:));
            end
        end
        
        function set_power(obj, pwr)
            if any(pwr < obj.min_pwr) % lets us put in a vector
                disp('Outside of range, cannot use this power'); 
                pwr = obj.min_pwr;
            end
            if ~isempty(obj.max_pwr) && any(pwr > obj.max_pwr)
                disp('Above max power, clamping to max');
                pwr = obj.max_pwr;
            end
            obj.pwr_request = pwr;
        end


        function set_shutter(obj, starts, durations)
            % ensure column
            if size(starts, 2) ~= 1
                error('not a col');
            end
            obj.shutter.set([starts, durations])
        end

        function set_shutter_old(obj, duration, on_time, frequency, delay)
            if nargin < 5 || isempty(delay)
                delay = 0;
            end
            obj.shutter_params.duration = duration; % how long the shutter is open for
            obj.shutter_params.on_time = on_time; % total on time...
            obj.shutter_params.frequency = frequency;
            obj.shutter_params.delay = delay;

            n_pulses = round(max(1, on_time/1000 * frequency));
            if ~isempty(n_pulses)
                cycle = (1/frequency) * 1000;
                obj.shutter.set(cat(2, [delay+1:cycle:delay+on_time]', duration * ones(n_pulses, 1)));
                obj.shutter_params = [];
            end
        end

        function power(obj, pwr)
            val = obj.pwr_fun(pwr);
            if isnan(val)
                disp('power out of range')
                return
            end
            obj.control.set(val);
            % obj.hwp.moveto(obj.pwr2deg(pwr_request));
        end

        function sweep = gated_waveform(obj)
            %GATED_WAVEFORM This trial's modulator command: rest, except during pulses.
            %   Sample count comes from the SweepGenerator on the analog line.
            %   TrialManager.prepare calls set_trial_length on every DAQOutput
            %   BEFORE modules.call('prepare'), so by the time we get here the
            %   generator already knows this trial's length.
            %
            %   Every failure path below returns the all-rest sweep rather than
            %   bailing out, so an unusable power request produces a DARK trial
            %   instead of leaving the previous trial's waveform on the modulator.
            %
            %   ONE CAVEAT, for a rig whose rest_value is not 0 V:
            %   TrialManager.prepare does `sweep(end,:) = 0` after concatenating
            %   every output, which forces the final sample of this column to 0 V
            %   rather than to rest_value. That is right for digital lines and for
            %   a gate whose off state is 0 V, but on a modulator resting at, say,
            %   -0.375 V it is a single-sample (50 us at 20 kHz) departure from
            %   rest at the very end of the trial. Measure it on your rig before
            %   trusting it; fixing it properly means teaching TrialManager each
            %   column's idle level, which is a change with much wider blast
            %   radius than this one.
            g = obj.control.interface.pulse;
            assert(~isempty(g), 'LaserPowerControl:notInitialized', ...
                ['The modulator''s analog output has no sweep generator, so this ' ...
                 'trial''s length is\nunknown. DAQOutput.initialize creates it, ' ...
                 'driven by TrialManager.initialize.']);

            n = round(g.sample_rate * g.sweep_length);
            sweep = repmat(obj.rest_value, n, 1);

            if isempty(obj.stim_starts) || isempty(obj.pwr_fun)
                return   % commanded dark this trial, or no LUT to convert with
            end

            val = obj.pwr_fun(obj.pwr_request);
            if ~isscalar(val) || isnan(val)
                warning('LaserPowerControl:powerOutOfRange', ...
                    ['Requested power does not map to a single command value ' ...
                     'through this channel''s\ncalibration, so it stays DARK this ' ...
                     'trial rather than delivering an unknown level.']);
                return
            end

            for i = 1:numel(obj.stim_starts)
                i0 = max(1, round(obj.stim_starts(i) * g.sample_rate) + 1);
                i1 = min(n, round((obj.stim_starts(i) + obj.stim_durations(i)) * g.sample_rate));
                if i1 >= i0
                    sweep(i0:i1) = val;
                end
            end
            sweep(end) = obj.rest_value;
        end

        function prepare(obj)
            % Waveform-gated channels build their whole trial here, because the
            % power command and the pulse timing are the same signal. Note the
            % early returns below all drive the control to REST rather than
            % returning silently: on this path "do nothing" leaves whatever the
            % last trial wrote sitting on the modulator.
            if strcmp(obj.gate_mode, 'waveform')
                obj.control.set(obj.gated_waveform());
                return
            end

            %prepare hwp if power set
            % if isempty(obj.control.interface.pulse.sweep)
                if ~isempty(obj.pwr_fun)
                    val = obj.pwr_fun(obj.pwr_request);
                    if isnan(val)
                        disp('power out of range')
                        return
                    end
                    obj.control.set(obj.pwr_fun(obj.pwr_request));
                end
            % end

            % % prepare shutter if shutter set
            % duration = obj.shutter_params.duration; % ms
            % on_time = obj.shutter_params.on_time; %ms
            % frequency = obj.shutter_params.frequency;
            % delay = obj.shutter_params.delay;
            % n_pulses = round(max(1, on_time/1000 * frequency));
            % if ~isempty(n_pulses)
            %     cycle = (1/frequency) * 1000;
            %     obj.shutter.set(cat(2, [delay+1:cycle:delay+on_time]', duration * ones(n_pulses, 1), ones(n_pulses, 1)));
            %     obj.shutter_params = [];
            %     % obj.close_all();
            % end
        end
    end
end
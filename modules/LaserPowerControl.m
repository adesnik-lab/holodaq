classdef LaserPowerControl < Module
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
    end

    methods
        function obj = LaserPowerControl(shutter, control, path_to_lut, current_khz)
            if nargin < 3 || isempty(path_to_lut)
                calib = [];
            else
                calib = importdata(path_to_lut);
            end

            if nargin < 4 || isempty(current_khz)
                current_khz = calib.khz;
                fprintf('Assuming calibration khz (%dkHz)\n', calib.khz)
            end

            if ~isempty(calib)
                obj.get_pwr_fun(calib, current_khz);
            end
            obj.shutter = shutter;
            obj.control = control;
            obj.pwr_request = obj.min_pwr;
        end
        
        function get_pwr_fun(obj, calib, current_khz)
            scale = current_khz/calib.khz;
            % get unique only
            [~, u_idx] = unique(calib.powers);
            obj.pwr_fun = @(x) interp1(calib.powers(u_idx)*scale, calib.degrees(u_idx), x);
            % when generating this, maybe set some things..
            % obj.max_deg = calib.degrees(end);
            % obj.min_deg = calib.degrees(1);
            obj.max_pwr = calib.max_power*scale;
            obj.min_pwr = calib.min_power*scale;
        end
        
        % function control = pwr2con(obj, pwr_request)
        %     control = obj.pwr_fun(pwr_request);
        % end

        function open(obj)
            sweep = zeros(1, obj.shutter.interface.n_outputs);
            sweep(obj.shutter.interface.channel_idx) = 1;
            obj.shutter.interface.io.write(sweep);
        end 

        function close_all(obj)
            % this is kinda meh rn, because it closes everything, but
            % that's fine
            sweep = zeros(1, obj.shutter.interface.n_outputs);
            sweep(obj.shutter.interface.channel_idx) = 0;
            obj.shutter.interface.io.write(sweep); % ew
        end

        function zero(obj)
            obj.control.set(obj.pwr_fun(obj.min_pwr));
            % obj.hwp.moveto(obj.min_deg)
            obj.close_all()
        end

        function set(obj, s)
            % use the stiminfo to generate EVERYTHING you might need
            % first let's unpack the stim info
            % power control
            % convert from power to power per cell...
            obj.set_power(s.power/s.sequence.average_de);
            
            % ok... now we need to set the shutter, but it might be weird?
            % (idk)
            %timing now..
            obj.set_shutter(s.pulse_start', s.pulse_duration');
        end
        
        function set_power(obj, pwr)
            if any(pwr < obj.min_pwr) % lets us put in a vector
                disp('Outside of range, cannot use this power'); 
                obj.pwr = obj.min_pwr;
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
            obj.control.set(obj.pwr_fun(pwr));
            % obj.hwp.moveto(obj.pwr2deg(pwr_request));
        end

        function prepare(obj)
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
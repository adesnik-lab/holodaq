classdef FiberPowerControl < Module
    properties
        shutter
        hwp

        pwr_fun
        pwr

        shutter_params
        min_deg
        max_deg
        min_pwr
        max_pwr
    end

    methods
        function obj = FiberPowerControl(shutter, hwp, path_to_lut, current_khz)
            if nargin < 3 || isempty(path_to_lut)
                calib = [];
            else
                calib = importdata(path_to_lut);
            end

            if nargin < 4 || isempty(current_khz)
                current_khz = calib.khz;
                fprintf('Assuming calibration khz (%dkHz)\n', calib.khz)
            end

            obj.get_pwr_fun(calib, current_khz);
            obj.shutter = shutter;
            obj.hwp = hwp;
            obj.pwr = obj.min_pwr;
        end
        
        function get_pwr_fun(obj, calib, current_khz)
            scale = current_khz/calib.khz;
            obj.pwr_fun = @(x) interp1(calib.powers*scale, calib.degrees, x);
            obj.max_deg = calib.degrees(end);
            obj.min_deg = calib.degrees(1);
            obj.max_pwr = calib.max_power*scale;
            obj.min_pwr = calib.min_power*scale;
        end
        
        function deg = pwr2deg(obj, pwr)
            deg = obj.pwr_fun(pwr);
            if isnan(deg)
                disp('Outside of range, cannot use this power');
                deg = obj.min_deg; % set to min just in case
            end
        end

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
            obj.hwp.moveto(obj.min_deg)
            obj.close_all()
        end
        
        function set_power(obj, pwr)
            obj.pwr = pwr;
            obj.pwr2deg(pwr); % run checks
        end

        function set_shutter(obj, duration, on_time, frequency, delay)
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
                % obj.close_all();
            end
        end

        function power(obj, pwr)
            obj.hwp.moveto(obj.pwr2deg(pwr));
        end

        function prepare(obj)
            % prepare hwp if power set
            if ~isempty(obj.pwr_fun)
                obj.hwp.moveto(obj.pwr2deg(obj.pwr));
            end

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
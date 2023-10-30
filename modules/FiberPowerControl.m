classdef FiberPowerControl < Module
    properties
        shutter
        hwp
        pwr_fun
        min_deg
        max_deg
        min_pwr
        max_pwr
    
        pwr;
        duration
        delay
        on_time
        frequency
    end

    methods
        function obj = FiberPowerControl(shutter, hwp, path_to_lut)
            if nargin < 3 || isempty(path_to_lut)
                calib = [];
            else
                calib = importdata(path_to_lut);
            end

            obj.get_pwr_fun(calib);
            obj.shutter = shutter;
            obj.hwp = hwp;
            obj.hwp.moveto(obj.min_deg);
            obj.pwr = obj.min_pwr;
        end
        
        function get_pwr_fun(obj, calib)
            obj.pwr_fun = @(x) interp1(calib.powers, calib.degrees, x);
            obj.max_deg = calib.degrees(end);
            obj.min_deg = calib.degrees(1);
            obj.max_pwr = calib.max_power;
            obj.min_pwr = calib.min_power;
        end
        
        function deg = pwr2deg(obj, pwr)
            deg = obj.pwr_fun(pwr);
            if isnan(deg)
                error('Outside of range, cannot use this power');
            end
        end

        function open(obj)
            sweep = zeros(1, obj.shutter.io.n_outputs);
            sweep(obj.shutter.io.channel_idx) = 1;
            obj.shutter.io.interface.write(sweep);
        end 

        function close_all(obj)
            % this is kinda meh rn, because it closes everything, but
            % that's fine
            sweep = zeros(1, obj.shutter.io.n_outputs);
            sweep(obj.shutter.io.channel_idx) = 0;
            obj.shutter.io.interface.write(sweep);
        end

        function zero(obj)
            obj.hwp.moveto(obj.min_deg)
            obj.close_all()
        end
        
        function set_delay(obj, delay)
            obj.delay = delay;
        end

        function set_power(obj, pwr)
            obj.pwr = pwr;
            obj.pwr2deg(pwr); % run checks
        end
        
        function set_duration(obj, duration)
            obj.duration = duration; %ms
        end

        function set_ontime(obj, on_time)
            obj.on_time = on_time; %ms
        end

        function set_frequency(obj, frequency)
            obj.frequency = frequency; %1/s (hz)
        end

        function power(obj, pwr)
            obj.hwp.moveto(obj.pwr2deg(pwr));
        end

        function prepare(obj)
<<<<<<< HEAD
            if ~isempty(obj.pwr_fun)
                obj.hwp.moveto(obj.pwr2deg(obj.pwr));
            end

            n_pulses = max(1, obj.on_time/1000 * obj.frequency);
            if ~isempty(n_pulses)
            cycle = (1/obj.frequency) * 1000;
            obj.shutter.set(cat(2, [obj.delay+1:cycle:obj.delay+obj.on_time]', obj.duration * ones(n_pulses, 1), ones(n_pulses, 1)));
            obj.on_time = [];
            obj.frequency = [];
            obj.duration = [];
=======
            if ~isempty(obj.hwp_lut)
                obj.hwp.moveto(obj.pwr2deg(obj.pwr));
                obj.shutter
>>>>>>> cf3a8d9 (reorg and update)
            end
        end

        % function deg = pwr2deg(obj, pwr)
        %     if isempty(obj.hwp_lut)
        %         warning('No LUT provided, cannot convert.')
        %         return
        %     end
        % 
        %     if pwr > obj.hwp_lut.max_power
        %         fprintf('Set to max power (%0.02fmW)\n', obj.hwp_lut.max_power);
        %         deg = obj.hwp_lut.max_deg;
        %         return
        %     end
        % 
        %     if pwr < obj.hwp_lut.min_power
        %         fprintf('Set to min power (%0.02fmW)\n', obj.hwp_lut.min_power);
        %         deg = obj.hwp_lut.min_deg;
        %         return
        %     end
        % 
        %     deg = obj.hwp_lut.f(pwr);
        % 
        % end
    end
end
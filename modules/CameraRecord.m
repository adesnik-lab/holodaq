classdef CameraRecord < Module
    properties
        vid
        crop_rect
        frames
        time_stamps
        is_acquiring = false
        start_time
        camera_type
        save_prefix
        timer
    end

    methods
        function obj = CameraRecord(crop_rect, exposure, white_balance, gain, camera_type, save_prefix)
            if nargin < 6, save_prefix = 'CAM'; end
            if nargin < 5, camera_type = 'winvideo'; end
            if nargin < 4, gain = 1; end
            if nargin < 3, white_balance = 3000; end
            if nargin < 2, crop_rect = [0,200,400,250]; end

            obj.crop_rect = crop_rect;
            obj.camera_type = camera_type;
            obj.save_prefix = save_prefix;
            obj.frames = {};
            obj.time_stamps = [];
            obj.initialize_camera(exposure, white_balance, gain);
        end

        function initialize_camera(obj, exposure, white_balance, gain)
            if ~isempty(obj.vid) && isvalid(obj.vid)
                stop(obj.vid); delete(obj.vid); imaqreset;
            end
            obj.vid = videoinput(obj.camera_type, 1, 'YUY2_640x480');
            obj.vid.ReturnedColorSpace = 'rgb';
            src = getselectedsource(obj.vid);
            src.ExposureMode = 'manual';
            src.Exposure = exposure;
            src.WhiteBalanceMode = 'manual';
            src.WhiteBalance = white_balance;
            src.Gain = gain;
            obj.vid.FramesPerTrigger = Inf;
        end

        function start_acquisition(obj)
            obj.frames = {};
            obj.time_stamps = [];
            start(obj.vid);
            obj.is_acquiring = true;
            obj.start_time = tic;

            obj.timer = timer( ...
                'ExecutionMode', 'fixedSpacing', ...
                'Period', 0.01, ...
                'TimerFcn', @(~,~) obj.grab_frame());
            start(obj.timer);
        end

        function stop_acquisition(obj)
            if obj.is_acquiring
                obj.is_acquiring = false;
                stop(obj.vid);

                if isvalid(obj.timer)
                    stop(obj.timer);
                    delete(obj.timer);
                end
            end
        end

        function grab_frame(obj)
            if obj.is_acquiring && obj.vid.FramesAvailable > 0
                frame = getdata(obj.vid, 1);
                frame = imcrop(rgb2gray(frame), obj.crop_rect);
                obj.frames{end+1} = frame;
                obj.time_stamps(end+1) = toc(obj.start_time);
            end
        end

        function [frames, ts] = get_data(obj)
            frames = obj.frames;
            ts = obj.time_stamps;
        end
    end
end

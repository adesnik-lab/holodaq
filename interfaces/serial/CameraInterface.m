classdef CameraInterface < Module
    properties
        camera_obj
        latest_frames
        latest_timestamps
    end

    methods
        function obj = CameraInterface(camera_obj)
            obj.camera_obj = camera_obj;
        end

        function start(obj)
            obj.camera_obj.start_acquisition();
        end

        function stop(obj)
            obj.camera_obj.stop_acquisition();
        end

        function out = gets_data(obj)
            [frames, ts] = obj.camera_obj.get_data();
            obj.latest_frames = frames;
            obj.latest_timestamps = ts;

            out.([obj.camera_obj.save_prefix '_frames']) = frames;
            out.([obj.camera_obj.save_prefix '_timestamps']) = ts;
        end

    end
end

classdef PTBReceiver < Receiver
    properties
        expts struct
    end

    methods
        function obj = PTBReceiver()
            obj = obj@Receiver('ptb');
        end

        function run(obj)
            % ex: expts.fanocon = @fanofactor_contrast_stimulus
            addpath('C:\Users\holos\OneDrive\Documents');
            feval(config.vis_stim);
        end
    end
end
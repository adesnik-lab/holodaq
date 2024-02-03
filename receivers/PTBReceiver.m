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
            stim_database; % bad don't like itn
            feval(stims.(obj.config.experiment));
        end
    end
end
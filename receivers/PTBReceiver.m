classdef PTBReceiver < Receiver
    properties
        expts struct
    end

    methods
        function obj = PTBReceiver(expts)
            obj = obj@Receiver('ptb');
            obj.expts = expts;
        end

        function run(obj)
            % ex: expts.fanocon = @fanofactor_contrast_stimulus
            feval(obj.expts.(obj.config.experiment));
        end
    end
end
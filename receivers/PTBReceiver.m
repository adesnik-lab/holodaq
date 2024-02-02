classdef PTBReceiver < Receiver
    properties
        expts
    end

    methods
        function obj = PTBReceiver(expts)
            obj = obj@Receiver('ptb');
            obj.expts = expts;
        end

        function run(obj)
            % get info from the config here and do something...
            obj.expts.(fanocon)
            switch obj.config.experiment
                case 'fanocon'
                    % run some kinda thing here
                case 'oricon'
                    % run something else here...
            end
        end
    end
end
classdef SIReceiver < Receiver
    properties
    end

    methods
        function obj = SIReceiver()
            obj = obj@Receiver('si');
        end

        function run(obj)
            % get info from config
            % set trigger
            % set filename
            % start loop
            % enable callbacks?
            
        end

        function callback(obj, expt)
            switch expt
                case 'oricon'
                    % set the oricon callback
                otherwise
                    % turn off callbacks
            end
        end
    end
end
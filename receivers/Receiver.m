classdef Receiver < handle
    properties
        interface
        config
    end

    methods
        function obj = Receiver(name)
            obj.interface = HolochatInterface(name, [], false);
            obj.config = obj.interface.get_config();
            obj.wait_for_go();
            obj.run();
        end

        function wait_for_go(obj)
            disp('Waiting for other computer...')
            out = obj.interface.read(300);
            if ~strcmp(out, 'go')
                error('not go');
            end
        end

        function run(obj)
        end
    end
end
classdef PTBComputer < Module
    properties
        trigger
        stim_onoff
        stim_id
        controller

        delay = 0
    end
    
    methods
        function obj = PTBComputer(trigger, stim_onoff, stim_id)
            obj.trigger = trigger;
            obj.stim_onoff = stim_onoff;
            obj.stim_id = stim_id;
            obj.controller = HolochatInterface('daq');
        end

        function set_delay(obj, delay)
            obj.delay = delay;
        end

        function send_stim_idx(obj, idx)
            obj.controller.send(idx, 'ptb');
        end
        function prepare(obj)
            obj.trigger.set([1+obj.delay, 25, 1])
            obj.prepare@Module(); % again, not sure here
        end
    end
end
classdef LaserEOM < Module
properties
    trigger
    saver
end

methods
    function obj = LaserEOM(dq, channel)
        io = DAQOutput(dq, channel);
        obj.trigger = Output(io);
        % obj.saver = Saver('LaserEOM');
    end
    
    function prepare(obj)
        obj.trigger.prepare();
    end

    % function store_trial_data(obj)
    %     obj.saver.store(obj.trigger.sweep);
    % end
end
end
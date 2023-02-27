classdef LaserEOM < Module
properties
end

methods
    function obj = LaserEOM(dq, channel)
        io = DAQInterface(dq, channel);
        controller = DAQOutputController(io);
        obj = obj@Module(controller);
    end
end

end
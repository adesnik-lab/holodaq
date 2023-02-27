classdef InputController < Controller
properties
end

methods
    function obj = InputController()
        obj = obj@Controller();
        obj.direction = 'input';
    end
end
end
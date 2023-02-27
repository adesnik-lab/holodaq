classdef Module < dynamicprops
    properties
        controller
        submodules
    end
    
    methods
        function obj = Module(controller)
            obj.controller = controller;
            obj.submodules = ModuleManager();
        end
        
        function initialize(obj)
            obj.controller.initialize();
        end
        
        function out = prepare(obj)
            out = obj.controller.prepare();
        end
        
        function add_submodule(submodule)
            obj.submodules.add(submodule)
        end
    end
end
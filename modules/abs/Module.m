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
            obj.submodules.call('initialize');
        end
        
        function out = prepare(obj)
            out = obj.controller.prepare();
            obj.submodules.call('prepare');
        end
        
        function add_submodule(obj, submodule)
            obj.submodules.add(submodule);
        end
    end
end
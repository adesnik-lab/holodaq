classdef Controllee < handle
    properties
        io
        
        id
        controller
    end

    methods
        function obj = Controllee(io, id)
            obj.io = io;
            obj.id = id;
        end

        function initialize(obj)
            obj.io.connect();
            obj.controller = obj.io.read();
            obj.io.send(obj.id);
        end

        function loop(obj)
            fprintf('Entering evaluate mode...\n')
            out = [];
            while true
                pause(0.1);
                cmd = obj.io.listen();         
                fprintf('>> %s\n', cmd);
                if strcmp(cmd, 'stoploop')
                    break
                end
                try
                    out = evalin('base', cmd);
                catch
                    try
                        evalin('base', cmd); % when sending things that have = signs, it doesn't like it
                    catch ME
                        disp(ME.message);
                    end
                end
                % try 
                %     out = evalin('base', cmd);
                % catch ME
                %     switch ME.identifier
                %         case 'MATLAB:TooManyOutputs'
                %             evalin('base', cmd);
                %         case 'MATLAB:m_invalid_lhs_of_assignment'
                %             evalin('base', cmd); % when sending things that have = signs, it doesn't like it
                %         otherwise
                %             disp(ME.message)
                %     end
                % end
                if ~isempty(out)
                    obj.io.send(out);
                    disp(out);
                    out = [];
                end
            end
        end

    end
end
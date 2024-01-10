classdef SerialInterface < Interface
    properties
    end
        
    methods
        function obj = SerialInterface(serial_obj)
            obj.io = serial_obj;
        end

        function writeline(obj, data)
            obj.io.writeline(data);
        end

        function out = readline(obj, disp_flag)
            if nargin < 2 || isempty(disp_flag)
                disp_flag = false;
            end
            out = obj.io.readline();
            if disp_flag
                disp(out);
            end
        end

        function query(obj, query)
            obj.writeline(query);
            obj.readline(true);
        end

        function flush(obj)
            obj.io.flush();
        end

        function out = get_data(obj)
            out = [];
        end
    end

end
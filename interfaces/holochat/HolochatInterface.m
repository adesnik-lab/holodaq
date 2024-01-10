classdef HolochatInterface < Interface
    properties
        server
        id
        ops

        debug = false
    end

    methods
        function obj = HolochatInterface(id, server)
            if nargin < 2 || isempty(server)
                server = 'http://136.152.58.120:8000';
            end

            obj.server = server;
            obj.id = id;
            obj.ops = weboptions('MediaType', 'application/json');
        end
        
        function initialize(obj)
        end
        
        function send(obj, data, dest)
            try
               recv = webwrite(obj.get_url('msg', dest), obj.encode(data), obj.ops);
            catch ME
                warning(ME.message);
            end
            if obj.debug
                disp(recv)
            end
        end
        
        function [out, recv] = read(obj, timeout)
            if nargin < 2 || isempty(timeout)
                timeout = 5;
            end
            ops = obj.ops;
            ops.Timeout = timeout;

            try
                recv = webread(obj.get_url('msg', obj.id), ops);
            catch ME
                warning(ME.message);
                if strcmp(ME.identifier, 'MATLAB:webservices:HTTP404StatusCodeError')
                    return
                end
            end

            if strcmp(recv.message_status, 'read')
                return
            end

            out = jsondecode(recv.message);
            if obj.debug
                disp(recv)
            end
        end
        
        function config(obj, data, dest)
            webwrite(obj.get_url('config', dest), obj.encode(data), obj.ops);
        end

        function flush(obj)
            try
                webread(obj.get_url('msg', obj.id), weboptions('RequestMethod', 'delete')); % delete everything on the server?? (bad?)
            end
        end

        function out = encode(obj, data)
            out = struct();
            out.sender = obj.id;
            out.message = jsonencode(data);
            out = jsonencode(out); % wrap everything ok
        end

        function reset(obj)
            try
                webread(obj.get_url('db', obj.id), weboptions('RequestMethod', 'delete'));
            end
        end

        function url = get_url(obj, path, target)
            if nargin < 3 || isempty(target)
                target = [];
            end
            url = sprintf('%s/%s/%s', obj.server, path, target) ;
        end
    end
end
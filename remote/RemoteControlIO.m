classdef RemoteControlIO < handle
    %REMOTECONTROLIO Minimal HTTP client for the phone-control server.
    %   Mirrors the holochat webread/webwrite polling pattern (see
    %   interfaces/holochat/RESTio.m) but uses stock jsonencode/jsondecode
    %   (no mps / MATLAB Production Server dependency) and a short timeout, and
    %   NEVER throws: a network error yields empty / a no-op, so it is safe to
    %   call from a timer callback or an experiment event listener.
    %
    %   Endpoints (all under <base>, e.g. http://127.0.0.1:8765/api):
    %       GET  /cmd/pop      -> {commands:[...]}   (consume-once queue)
    %       POST /status       <- status struct       (persistent board)
    %       GET  /heartbeat    -> {phone_stale, ...}  (dead-man input)
    %       GET  /experiments  -> {experiments:[...]}

    properties
        base
        token
        getops
        postops
    end

    methods
        function obj = RemoteControlIO(base, token)
            if nargin < 1 || isempty(base), base = 'http://127.0.0.1:8765/api'; end
            if nargin < 2, token = ''; end
            obj.base  = regexprep(base, '/+$', '');
            obj.token = token;
            hdr = {'X-Auth-Token', token};
            obj.getops  = weboptions('MediaType', 'application/json', ...
                'HeaderFields', hdr, 'Timeout', 3, 'ContentType', 'json');
            obj.postops = weboptions('MediaType', 'application/json', ...
                'HeaderFields', hdr, 'Timeout', 3, 'RequestMethod', 'post');
        end

        function cmds = popCommands(obj)
            cmds = {};
            try
                recv = webread([obj.base '/cmd/pop'], obj.getops);
                cmds = RemoteControlIO.aslist(recv);
            catch ME
                obj.note('popCommands', ME);
            end
        end

        function ok = postStatus(obj, s)
            ok = false;
            try
                webwrite([obj.base '/status'], s, obj.postops);
                ok = true;
            catch ME
                obj.note('postStatus', ME);
            end
        end

        function hb = readHeartbeat(obj)
            hb = struct('ok', false, 'phone_stale', true, 'phone_last_seen', 0);
            try
                r = webread([obj.base '/heartbeat'], obj.getops);
                if isstruct(r)
                    hb = r;
                    hb.ok = true;
                end
            catch ME
                obj.note('readHeartbeat', ME);
            end
        end

        function exps = experiments(obj)
            exps = {};
            try
                recv = webread([obj.base '/experiments'], obj.getops);
                if isstruct(recv) && isfield(recv, 'experiments')
                    exps = RemoteControlIO.aslist(recv.experiments);
                end
            catch ME
                obj.note('experiments', ME);
            end
        end
    end

    methods (Access = private)
        function note(~, where, ME)
            % Surface a transport error once (dedup on message) so a server
            % that isn't up yet doesn't spam the console every poll.
            persistent lastmsg
            if ~strcmp(lastmsg, ME.message)
                warning('RemoteControlIO:%s: %s', where, ME.message);
                lastmsg = ME.message;
            end
        end
    end

    methods (Static)
        function list = aslist(x)
            % Normalize a webread result into a cell array of structs. Unwraps a
            % {commands:...} / {experiments:...} envelope if present.
            if isstruct(x) && isscalar(x) && isfield(x, 'commands')
                x = x.commands;
            elseif isstruct(x) && isscalar(x) && isfield(x, 'experiments')
                x = x.experiments;
            end
            if isempty(x)
                list = {};
            elseif iscell(x)
                list = x;
            elseif isstruct(x)
                list = num2cell(x);
            else
                list = {x};
            end
        end
    end
end

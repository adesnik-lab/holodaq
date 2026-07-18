classdef WebhookNotifier < Notifier
    % WebhookNotifier  Post a notification to a Slack or Discord webhook.
    %
    % Delivery is a single HTTP POST via stock MATLAB webwrite (no toolbox),
    % mirroring holodaq's RESTio. The webhook URL is passed in directly so the
    % framework stays free of any pref/secret handling -- callers supply the
    % URL (e.g. read from getpref in the scope2k wiring layer).
    %
    %   n = WebhookNotifier(url, 'slack');            % or 'discord'
    %   n.send('Run finished', 'mouse123 / epoch2 done');
    %
    % See also Notifier, NotificationManager, RESTio.

    properties
        url
        platform = 'slack';   % 'slack' | 'discord'
        timeout  = 5;         % seconds; short so a slow network never stalls
    end

    methods
        function obj = WebhookNotifier(url, platform, name)
            if nargin < 2 || isempty(platform), platform = 'slack'; end
            if nargin < 3 || isempty(name), name = sprintf('webhook-%s', platform); end
            obj@Notifier(name);
            obj.url = url;
            obj.platform = lower(platform);
        end

        function send(obj, subject, body, meta)
            if nargin < 3, body = ''; end
            if nargin < 4, meta = struct(); end %#ok<NASGU>  % reserved for richer payloads
            if isempty(obj.url)
                error('WebhookNotifier:noUrl', 'No webhook URL configured.');
            end

            text = obj.format(subject, body);
            payload = obj.build_payload(text);
            ops = weboptions('MediaType', 'application/json', 'Timeout', obj.timeout);
            webwrite(obj.url, payload, ops);
        end
    end

    methods (Access = private)
        function text = format(~, subject, body)
            if isempty(body)
                text = subject;
            else
                text = sprintf('*%s*\n%s', subject, body);
            end
        end

        function payload = build_payload(obj, text)
            % Slack expects {"text": ...}; Discord expects {"content": ...}.
            switch obj.platform
                case 'slack'
                    payload = struct('text', text);
                case 'discord'
                    payload = struct('content', text);
                otherwise
                    error('WebhookNotifier:badPlatform', ...
                        'Unknown platform "%s" (use slack or discord).', obj.platform);
            end
        end
    end
end

classdef NotificationManager < handle
    % NotificationManager  Registry + fault-tolerant broadcast for Notifiers.
    %
    % Holds a heterogeneous array of Notifier objects and fans a message out
    % to every enabled one. A notifier that errors only warns -- a failed
    % notification must never crash or block an experiment.
    %
    % Mirrors the slottable-module pattern of ModuleManager, but with a plain
    % Notifier array (matlab.mixin.Heterogeneous) rather than dynamicprops,
    % since notifiers are looked up by their .name field, not as properties.
    %
    % See also Notifier, WebhookNotifier, ModuleManager.

    properties
        notifiers = Notifier.empty;
    end

    methods
        function obj = NotificationManager()
        end

        function add(obj, notifier)
            obj.notifiers(end+1) = notifier;
        end

        function notify(obj, subject, body, meta)
            % Broadcast to every enabled notifier. Each send is isolated in a
            % try/catch so one bad channel can't take down the others (or the
            % experiment). meta is optional context passed through to send().
            if nargin < 3, body = ''; end
            if nargin < 4, meta = struct(); end
            for k = 1:numel(obj.notifiers)
                n = obj.notifiers(k);
                if ~n.enabled
                    continue
                end
                try
                    n.send(subject, body, meta);
                catch ME
                    warning('NotificationManager:sendFailed', ...
                        'Notifier "%s" failed: %s', obj.label(n), ME.message);
                end
            end
        end

        function enable(obj, name)
            obj.set_enabled(name, true);
        end

        function disable(obj, name)
            obj.set_enabled(name, false);
        end

        function list(obj)
            % Print the registered notifiers and their state.
            if isempty(obj.notifiers)
                fprintf('No notifiers registered.\n');
                return
            end
            for k = 1:numel(obj.notifiers)
                n = obj.notifiers(k);
                state = 'disabled';
                if n.enabled, state = 'enabled'; end
                fprintf('  [%s] %s (%s)\n', state, obj.label(n), class(n));
            end
        end
    end

    methods (Access = private)
        function set_enabled(obj, name, tf)
            hit = false;
            for k = 1:numel(obj.notifiers)
                if strcmp(obj.notifiers(k).name, name)
                    obj.notifiers(k).enabled = tf;
                    hit = true;
                end
            end
            if ~hit
                warning('NotificationManager:noSuchNotifier', ...
                    'No notifier named "%s".', name);
            end
        end

        function s = label(~, n)
            s = n.name;
            if isempty(s), s = class(n); end
        end
    end
end

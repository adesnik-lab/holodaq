classdef Notifier < matlab.mixin.Heterogeneous & handle
    % Notifier  Abstract base for a slottable notification channel.
    %
    % A Notifier is a self-contained delivery channel (Slack/Discord webhook,
    % email, SMS, ...) that a NotificationManager can broadcast to. Subclasses
    % override send() with their transport. Keep transport logic in the
    % subclass; this base only defines the interface and the enabled flag.
    %
    % See also NotificationManager, WebhookNotifier, Module.

    properties
        enabled = true;   % skipped by NotificationManager when false
        name    = '';     % human-readable label, used for enable/disable lookup
    end

    methods
        function obj = Notifier(name)
            if nargin >= 1 && ~isempty(name)
                obj.name = name;
            end
        end

        function send(obj, subject, body, meta)
            % Overwritten in subclass. subject/body are char; meta is an
            % optional struct of context (mouse, epoch, experiment, trial...).
            % No-op here so an un-overridden notifier is harmless.
        end
    end
end

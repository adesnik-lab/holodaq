classdef StubHolochat < handle
    %STUBHOLOCHAT Offline stand-in for HolochatInterface, for Receiver tests.
    %   Implements only what Receiver touches -- scan_config, set_config, flush --
    %   with canned replies, call counters and an optional fault injection, so the
    %   polling and timer lifecycle can be tested with no broker and no network.
    %
    %   Assigned straight onto Receiver.interface (a public property). Receiver's
    %   constructor is safe offline: HolochatInterface with reset=false only builds
    %   a RESTio, which stores a URL and weboptions and makes no request.
    %
    %   See also: test_receiver_async, CountingReceiver

    properties
        cfg     = struct()   % topic -> reply struct; [] or missing means "nothing there"
        throw_on_scan = false
        n_scan  = 0
        n_set   = 0
        n_flush = 0
        acks    = {}
    end

    methods
        function out = scan_config(obj, topic)
            obj.n_scan = obj.n_scan + 1;
            if obj.throw_on_scan
                error('StubHolochat:injected', 'injected network failure');
            end
            out = [];
            f = matlab.lang.makeValidName(char(topic));
            if isfield(obj.cfg, f), out = obj.cfg.(f); end
        end

        function set_config(obj, data, topic)
            obj.n_set = obj.n_set + 1;
            obj.acks{end+1} = struct('topic', char(topic), 'data', data);
        end

        function flush(obj)
            obj.n_flush = obj.n_flush + 1;
        end

        function post(obj, topic, value)
            %POST Test helper: put a reply on a topic the way the DAQ would.
            obj.cfg.(matlab.lang.makeValidName(char(topic))) = value;
        end
    end
end

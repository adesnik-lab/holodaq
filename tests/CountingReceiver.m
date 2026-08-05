classdef CountingReceiver < Receiver
    %COUNTINGRECEIVER Receiver subclass that records handler calls, for tests.
    %   Counts run/onAbort/onFinish instead of touching hardware, and can be made
    %   to throw from run() to exercise the prime-FAILED path.
    %
    %   See also: test_receiver_async, StubHolochat

    properties
        n_run = 0
        n_abort = 0
        n_finish = 0
        run_throws = false
        run_delay = 0        % s; simulate a slow prime (SIReceiver.run is not fast)
    end

    methods
        function obj = CountingReceiver(name)
            obj@Receiver(name);
            obj.interface = StubHolochat();   % never touch the network
        end

        function run(obj)
            obj.n_run = obj.n_run + 1;
            if obj.run_delay > 0, pause(obj.run_delay); end
            if obj.run_throws
                error('CountingReceiver:injected', 'injected prime failure');
            end
        end

        function onAbort(obj),  obj.n_abort  = obj.n_abort + 1;  end
        function onFinish(obj), obj.n_finish = obj.n_finish + 1; end
    end
end

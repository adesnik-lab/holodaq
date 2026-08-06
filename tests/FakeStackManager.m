classdef FakeStackManager < handle
    %FAKESTACKMANAGER Recording stand-in for hSI.hStackManager, for SIReceiver tests.
    %   Logs every property WRITE in order, so a test can assert not just the final
    %   values but the sequence -- which matters here: writing `enable` re-derives the
    %   counts in real ScanImage, so the guard must write enable BEFORE the counts.
    %
    %   `couple` reproduces that re-derivation: with it on, writing enable clobbers
    %   numVolumes/numSlices the way the real StackManager does. That IS the bug being
    %   guarded against, so the test has to be able to reproduce it.
    %
    %   `absent` hides a property, standing in for a ScanImage version that does not
    %   expose it -- getAcqCounts must leave it out rather than error.
    %
    %   Dependent properties over private backing fields, NOT plain properties with
    %   get./set. methods: a getter that reads its own property recurses forever in
    %   MATLAB (the same trap Pattern.get.id contains).
    %
    %   See also: test_si_acq_counts, FakeSI

    properties (Dependent)
        enable
        framesPerSlice
        numVolumes
        numSlices
    end

    properties
        writes = {}          % {name, value} in write order
        couple = false       % writing enable re-derives the counts, as ScanImage does
        absent = {}          % property names to hide from reads
        coupled_values = struct('numVolumes', 5, 'numSlices', 3)
    end

    properties (Access = private)
        enable_ = false
        framesPerSlice_ = 100
        numVolumes_ = 1
        numSlices_ = 1
    end

    methods
        function v = get.enable(obj),         v = obj.rd('enable',         obj.enable_);         end
        function v = get.framesPerSlice(obj), v = obj.rd('framesPerSlice', obj.framesPerSlice_); end
        function v = get.numVolumes(obj),     v = obj.rd('numVolumes',     obj.numVolumes_);     end
        function v = get.numSlices(obj),      v = obj.rd('numSlices',      obj.numSlices_);      end

        function set.framesPerSlice(obj, v)
            obj.wr('framesPerSlice', v); obj.framesPerSlice_ = v;
        end
        function set.numVolumes(obj, v)
            obj.wr('numVolumes', v); obj.numVolumes_ = v;
        end
        function set.numSlices(obj, v)
            obj.wr('numSlices', v); obj.numSlices_ = v;
        end

        function set.enable(obj, v)
            obj.wr('enable', v);
            obj.enable_ = v;
            if obj.couple
                % what the real StackManager does: re-derive the coupled geometry.
                % Written to the backing fields directly so the re-derivation shows
                % up as ScanImage's doing, not as a guard write in the log.
                obj.numVolumes_ = obj.coupled_values.numVolumes;
                obj.numSlices_  = obj.coupled_values.numSlices;
            end
        end

        function names = written(obj)
            %WRITTEN Property names in write order (values dropped).
            names = cellfun(@(w) w{1}, obj.writes, 'UniformOutput', false);
        end

        function reset_log(obj), obj.writes = {}; end
    end

    methods (Access = private)
        function v = rd(obj, name, v)
            if any(strcmp(name, obj.absent))
                error('FakeStackManager:absent', ...
                    'this ScanImage version has no %s', name);
            end
        end

        function wr(obj, name, value)
            if any(strcmp(name, obj.absent))
                error('FakeStackManager:absent', ...
                    'this ScanImage version has no %s', name);
            end
            obj.writes{end+1} = {name, value};
        end
    end
end

classdef SLMComm < Module
%SLMCOMM  Fires the SLM's advance trigger, one pulse per stim in the sequence.
%
%   Two constants, and they do DIFFERENT jobs -- they used to both be 0.025, which
%   made it easy to think they were one thing:
%
%   pre_delay      how far AHEAD of the light the trigger edge goes, so the panel has
%                  settled by the time the pulse arrives. This is about liquid-crystal
%                  response and is unchanged.
%   trigger_width  how long the line is held high. This is what sets the MINIMUM
%                  SPACING between stims: the trigger for a pulse at t occupies
%                  [t - pre_delay, t - pre_delay + trigger_width], so two pulses dt
%                  apart give windows that abut at dt == trigger_width and overlap
%                  below it. Merged windows are ONE rising edge, and PlaySequence2K
%                  advances one frame per edge, so the sequence slides out of step and
%                  later pulses fire on whatever hologram is still displayed. The laser
%                  gate is unaffected, so the light still looks correct.
%
%   trigger_width was 0.025, which put the floor at 25 ms and silently broke any
%   experiment stepping holograms faster than that -- measured on the real
%   PulseGenerator: 10 pulses at 20 ms produced 1 rising edge. At 0.005 the floor is
%   5 ms. That is as fast as the hardware goes: PulseGenerator.default_trig_length is
%   0.005 and it silently widens anything shorter back up to it.
%
%   Note the edge still leads the light by pre_delay (25 ms); only the high time got
%   shorter, so nothing about SLM settling changed.
%
%   StimInfo warns when a sequence asks for spacing under trigger_width, and reads this
%   constant so the two cannot drift apart.

    properties (Constant)
        pre_delay = 0.025;      % s, how early the edge leads the light (settling)
        trigger_width = 0.005;  % s, high time; also the minimum stim-to-stim spacing
    end
    properties
        trigger
        flip
    end

    methods
        function obj = SLMComm(trigger, flip)
            obj.trigger = trigger;
            % obj.flip = flip;
        end

        function set(obj, s)
            for ps = s.pulse_start
                % start it a touch earlier to try to get it before
                obj.trigger.set([max(ps - obj.pre_delay, 0), obj.trigger_width]);
            end
        end
    end
end

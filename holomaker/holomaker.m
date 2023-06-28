classdef Holomaker < handle
    properties
        powerList
        waitList
        hzList
        pulseList
        holosPerCycle
        cellsPerHolo
        divTotalCells
        holoSets
        setlinks
        % these will be dynamically filled in subclasses?

        startTime = 1000;
        pulseDuration
        TrigDuration
        stimFreq
    end

    methods
        function obj = Holomaker()
            
        end

        function [slm, laser_eom] = makeHoloSequences_temp(obj, holoRequest, setKey, slm, laser_eom)
            seq = makeHoloSequences(holoRequest.holoStimParams, setKey);
            [slm, laser_eom] = makeHoloTrigSeqs2K(seq, holoRequest, slm, laser_eom);
            % probably here what we'll do is that we will output the pulse start, dur, and vals
        end

        function out = getLaserEOM(obj)
            out = obj.get_the_laser_eom_pulse_stuff();
            % calculate? or just get the parameters for the trigger
        end

        function out = getSLM(obj)
            out = obj.get_slm_pulse_stuff();
        end

        function set_key = generateSetKey(obj)
        end

        function chooseCellsToUse(obj)
        end
    end
end
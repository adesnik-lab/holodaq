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

        holosToUse
        totalCells
        
        rois
        setKey
    end

    methods
        function obj = Holomaker()
            
        end

        function [slm, laser_eom] = makeHoloSequences_temp(obj, holoRequest, setKey, slm, laser_eom)
            [slm, laser_eom] = makeHoloTrigSeqs2K(seq, holoRequest, slm, laser_eom);
            % probably here what we'll do is that we will output the pulse start, dur, and vals
        end

        function Seq = makeHoloSequences(obj, setKey)
            Seq=[];
            for i =1:numel(obj.hzList)
                tempSeq=[];
                n=0;
                for k=1:obj.repsList(i)
                    tempSeq =cat(2,tempSeq, ...
                        repmat(n+1:n+obj.holosPerCycle(i), ...
                        [1 obj.pulseList(i)]));
                    n=n+obj.holosPerCycle(i);
                end
                %then convert to use the correct set of holos
                thisHoloSet = obj.setKey{obj.holoSets(i)};
                temp = tempSeq;%added to help debug
                tempSeq = thisHoloSet(temp); 
                Seq{i}=tempSeq;
            end
        end

        function out = getLaserEOM(obj)
            out = obj.get_the_laser_eom_pulse_stuff();
            % calculate? or just get the parameters for the trigger
        end

        function out = getSLM(obj)
            out = obj.get_slm_pulse_stuff();
        end

        function [rois, set_key] = getSetKeyAndROI(obj)
        end

        function chooseCellsToUse(obj)
        end
    end
end
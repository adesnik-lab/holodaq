classdef Holomaker < handle
    properties
        holoRequest

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

        repsList
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
        function obj = Holomaker(holoRequest)
            obj.holoRequest = holoRequest;
        end

        function [slm, laser_eom] = makeHoloSequences_temp(obj, holoRequest, setKey, slm, laser_eom)
            % [slm, laser_eom] = makeHoloTrigSeqs2K(seq, holoRequest, slm, laser_eom);
            % probably here what we'll do is that we will output the pulse start, dur, and vals
        end


        function holosocket = run(obj)
            obj.getSetKeyAndROI();
            obj.holoRequest.rois = obj.rois;
            % temporarily put here
            obj.repsList = floor(length(obj.holosToUse)./obj.holosPerCycle); 
 
            disp('Run code on Holo computer then press any key to continue...')
            pause

            holosocket = obj.connectToOtherComputer();
        end

        function out = getMaxSeqDur(obj)
            out = obj.repsList./obj.hzList.*obj.pulseList+obj.startTime/1000;
        end
    
        function holoSocket = connectToOtherComputer(obj)
            holoSocket = msocketPrep;
            obj.holoRequest = transferHRNoDAQ(obj.holoRequest, holoSocket);
        end

        function getTotalCells(obj)
            if obj.holosToUse==0
                obj.totalCells =size(obj.holoRequest.targets,1);
                %disp(['Total Cells Detected ' num2str(totalCells)]);
                obj.holosToUse = 1:obj.totalCells;
            elseif iscell(obj.holosToUse)
                obj.totalCells = numel(unique([obj.holosToUse{:}]));
                %disp(['Using ' num2str(totalCells) ' Cells']);
            else
                obj.totalCells = numel(obj.holosToUse);
                %disp(['Using ' num2str(totalCells) ' Cells']);
            end
        end

        function determineSequenceLength()
        end

        function Seq = makeHoloSequences(obj)
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
    

        function out = getHoloStimParams(obj)
            out = struct(obj); % this migth be funky but let's try it?
        end

        function chooseCellsToUse(obj)
        end
    end
end
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


        function run(obj)
            % obj.getSetKeyTest();
            obj.getSetKeyAndROI();
            obj.holoRequest.rois = obj.rois;
            obj.repsList = floor(length(obj.holosToUse)./obj.holosPerCycle); 


            % holosocket = obj.connectToOtherComputer();
        end

        function out = getMaxSeqDur(obj)
            out = obj.repsList./obj.hzList.*obj.pulseList+obj.startTime/1000;
        end
    

        function getTotalCells(obj)
            if ~iscell(obj.holosToUse) && all(obj.holosToUse == 0) % on the initial run, if there's no requested holograms, it'll just go ahead and use em all
                obj.totalCells =size(obj.holoRequest.targets, 1);
                obj.holosToUse = 1:obj.totalCells;
            elseif iscell(obj.holosToUse)
                obj.totalCells = numel(unique([obj.holosToUse{:}]));
                obj.holosToUse = obj.holosToUse{:};
            else
                obj.totalCells = numel(obj.holosToUse);
            end
        end

        function stim_times = set_slm_triggers(obj, slm)
            sequence = obj.makeHoloSequences();
            holoStimParams = obj.getHoloStimParams();
            disp('Making Sequences...')

            if ~isfield(holoStimParams,'visStartTime')
                holoStimParams.visStartTime = holoStimParams.startTime-80;
            end
            disp('Saved Control Output');

            c = 0; %count the output number
            for i = 1:numel(sequence) %Each type of stim
                for p = 1:numel(holoStimParams.powerList{i})
                    c=c+1;
                    
                    pulseStart = holoStimParams.startTime - holoStimParams.TrigDuration;
                    counter = 1;
                    Hz = holoStimParams.hzList(i);
                    for R = 1:holoStimParams.repsList(i) %Repeat with a different number of cells
                        try
                            pulseStart = pulseStart + holoStimParams.bwnGroupPause;
                        catch
                        end
                            
                        for Pulse = 1:holoStimParams.pulseList(i)
                            tm = pulseStart;
                            pulseStart = pulseStart + (1000/Hz) ;
                            for Ce = 1:holoStimParams.holosPerCycle(i)
                                counter=counter+1;
                                slm.trigger.set([tm, holoStimParams.TrigDuration, 5]);

                                tm=tm+holoStimParams.waitList(i)+ ...
                                    holoStimParams.TrigDuration;

                                tm=tm+holoStimParams.pulseDuration-holoStimParams.TrigDuration;
                                
                                if tm>pulseStart
                                    disp('Potential error in timing, probably something is wrong')
                                end
                            end
                        end
                    end
                end
            end
            stim_times = 0; % WORK ON THIS TM
        end

        function Seq = makeHoloSequences(obj)
            Seq = cell(numel(obj.hzList), 1);
            for i = 1:numel(Seq) 
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

        function rois = makeHoloRois(obj, nPerHolo, order)
            %make as many holos as necessary to get order, but don't make any
            %partial ones
            nHolos = floor(length(order)/nPerHolo);
        %     disp(nHolos)
            for i=1:nHolos
                rois{i} = order((i-1)*nPerHolo+1:i*nPerHolo);
            end
        end

        function getSetKeyTest(obj,  randomize)
            if nargin < 2 || isempty(randomize)
                randomize = false;
            end
            
            obj.getTotalCells();

            obj.rois = [];
            obj.setKey = {};

            nHolos = floor(obj.totalCells./obj.divTotalCells./obj.cellsPerHolo); %only make complete holograms
            setlink_orders = cell(max(obj.setlinks),1);
            for iset = unique(obj.holoSets)
                set_idx = find(obj.holoSets == iset);

                if length(set_idx) > 1
                    error('Holoset has multiple cellsperHolo or nHolos');
                    continue
                end

                nPerHolo = obj.cellsPerHolo(set_idx);
                nHolo = nHolos(set_idx);
                this_set_order = 1:obj.totalCells;
                
                if randomize
                    this_set_order = this_set_order(randperm(obj.totalCells));
                end

                if obj.setlinks(set_idx)>0
                    this_setlink = obj.setlinks(set_idx);
                    %if already has an order, override the generated one
                    if ~isempty(setlink_orders{this_setlink})
                        this_set_order = setlink_orders{this_setlink};
                    end
                    %replace the setlink_orders with only the unused rois
                    setlink_orders{this_setlink} = this_set_order(nHolo*nPerHolo+1:end);
                end
                this_set_order = this_set_order(1:nHolo*nPerHolo);
                these_rois = obj.makeHoloRois(nPerHolo,this_set_order);
                obj.setKey{iset} = [numel(obj.rois) + 1 : numel(obj.rois) + numel(these_rois)];
                obj.rois = [obj.rois, these_rois];%cellfun(@(x) obj.holosToUse(x),these_rois,'uniformoutput', 1)];
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
            % this is overloaded in children
        end
    

        function out = getHoloStimParams(obj)
            out = struct(obj); % this migth be funky but let's try it?
        end

        function chooseCellsToUse(obj)
        end
    end
end

classdef PowerCurve < Holomaker
    properties
    end
    
    methods
        function obj = PowerCurve(holoRequest, power)
            obj = obj@Holomaker(holoRequest);
            obj.holosToUse = 0;
            numHolos = numel(obj.holosToUse); % where is this from?
            % for k= 1:numel(stimTypeNumPulse)
            


            obj.powerList       = { power };
            obj.waitList        = [ 6 ]; %time after stim before next stim ms
            obj.hzList          = [ 30 ];
            obj.pulseList       = [ 5 ]; %previously 10; 5 is standard as of 5/15/19
            obj.holosPerCycle   = [ 1 ]; %groups to interleave
            obj.cellsPerHolo    = [ 1 ]; %number of cells per holo
            obj.divTotalCells   = [ 1 ]; %divide total number of holos
            obj.holoSets        = [ 1 ]; %unique groups of cells per
            obj.setlinks        = [ 1 ];
            % obj.bwnGroupPause   = [ 10 ]; %pause between groups in ms (default 10ms for normal 250 for detailed
       
            obj.getTotalCells();

            % obj.repsList = floor(numHolos./obj.holosPerCycle); 

            % more stuff here, general info?
            % need repsList, pulseList, holosPerCycle, pulseList, holoSets, hzList
            
            obj.startTime = 1000;
            obj.pulseDuration = 5;
            obj.TrigDuration = 5;
            obj.stimFreq = 1;
        end
        
        function getSetKeyAndROI(obj,  randomize)
            if nargin < 2 || isempty(randomize)
                randomize = false;
            end

            obj.rois = {};
            obj.setKey = {};
            these_rois=[];
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

                % if length(unique(obj.cellsPerHolo(obj.holoSets==iset))) > 1 || length(unique(nHolos(obj.holoSets==iset))) > 1 ||  length(unique(obj.setlinks(obj.holoSets==iset))) > 1
                %     error('Holoset has multiple cellsPerHolo or nHolos');
                % else
                %     nPerHolo = obj.cellsPerHolo(find(obj.holoSets==iset,1)); %TODO error if there are multiple cell numbers for sets
                %     nHolo = nHolos(find(obj.holoSets==iset,1));
                % end
                %then create a unique + random order
                this_set_order = 1:obj.totalCells;
                if randomize
                    this_set_order = this_set_order(randperm(obj.totalCells));
                end
                    
                % this_set_order = 1:obj.totalCells;%randperm(totalCells);
                %check if this is part of a set
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
                %     these_rois = randperm(totalCells,nPerHolo); %temp stand in
                these_rois = makeHoloRois(nPerHolo,this_set_order);
                obj.setKey{iset} = [numel(obj.rois) + 1 : numel(obj.rois) + numel(these_rois)];
                obj.rois = [obj.rois, cellfun(@(x) obj.holosToUse(x),these_rois,'uniformoutput',0)];
            end
        end
    end
end
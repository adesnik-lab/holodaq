classdef FixedSeq < Holomaker
    properties
    end
    
    methods
        function obj = FixedSeq(holoRequest, p)
            obj = obj@Holomaker(holoRequest);
            obj.holosToUse = {1};
            numHolos = numel(obj.holosToUse); % where is this from?
            % for k= 1:numel(stimTypeNumPulse)
            
            stimTypeNumTarget = unique(cellfun(@(x) numel(x), obj.holosToUse)); %[3 10 25];%;[3 10];% 33];%[4 10];%[10 4 25];% 11];%[10 5 20]; %also dictates grouping needs to not be redundant
            stimTypeNumPulse = round(200./stimTypeNumTarget);%[33 20 10 5 3];%;[33 10];% 3]; %[25 10];% [10 25 4];% 10];%[10 20 5];
            stimTypeHz = stimTypeNumPulse;%[10 33 3];%10; [30 9];% 2.7];%[30 12]; %[12 30 4.8];% 12];%[15 30 7.5]; %added 10/3/19 to make all stims same length
            p = [0.05];
            c = 1;
            for i=1:numHolos
                k = find(stimTypeNumTarget==numel(obj.holosToUse{i}));
                obj.powerList{c}       = [p];
                obj.waitList(c)        = 10; %time after stim before next stim ms
                obj.hzList(c)          = stimTypeHz(k);  %30Hz
                obj.pulseList(c)       = stimTypeNumPulse(k); %5 is default
                obj.holosPerCycle(c)   = 1; %groups to interleave
                obj.cellsPerHolo(c)    = numel(obj.holosToUse{i});
                obj.divTotalCells(c)   = numHolos*numel(stimTypeNumPulse); %divide total number of holos %i don't think it matters
                obj.holoSets(c)        = c; %unique groups of cells per
                obj.setlinks(c)        = 1;
                c=c+1;
            end

            obj.getTotalCells();
            
            obj.repsList        = obj.divTotalCells./obj.divTotalCells;%floor(nHolos./holosPerCycle);  
            fprintf('Maximum sequence length: %0.02fs\n', obj.repsList./obj.hzList.*obj.pulseList+obj.startTime/1000);
            % more stuff here, general info?
            % need repsList, pulseList, holosPerCycle, pulseList, holoSets, hzList
            
            obj.startTime = 1000;
            obj.pulseDuration = 5;
            obj.TrigDuration = 5;
            obj.stimFreq = 1;
        end
        
        function getSetKeyAndROI(obj)
            for ii = 1:numel(obj.holosToUse)
                obj.rois{ii} = obj.holosToUse{ii};
                obj.setKey{ii} = ii;
            end
        end
    end
end
function Seq = makeHoloSequences(holoStimParams, setKey)
    Seq=[];
    for i =1:numel(holoStimParams.hzList)
        tempSeq=[];
        n=0;
        for k=1:holoStimParams.repsList(i)
            tempSeq =cat(2,tempSeq, ...
                repmat(n+1:n+holoStimParams.holosPerCycle(i), ...
                [1 holoStimParams.pulseList(i)]));
            n=n+holoStimParams.holosPerCycle(i);
        end
        %then convert to use the correct set of holos
        thisHoloSet = setKey{holoStimParams.holoSets(i)};
        temp = tempSeq;%added to help debug
        tempSeq = thisHoloSet(temp); 
        Seq{i}=tempSeq;
    end
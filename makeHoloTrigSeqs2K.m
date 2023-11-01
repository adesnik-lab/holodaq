function [slm] = makeHoloTrigSeqs2K(Seq, fs, slm)
holoStimParams = fs.getHoloStimParams();

disp('Making Sequences...')

if ~isfield(holoStimParams,'visStartTime')
    holoStimParams.visStartTime = holoStimParams.startTime-80;
end
disp('Saved Control Output');

c = 0; %count the output number
for i = 1:numel(Seq) %Each type of stim
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

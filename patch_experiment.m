%% TO DO

clear
close all
clc

%% PARAMS

%%
default_setup();
sm = SessionManager(tm, 'bleh');

%% Modules
si = SIComputer(Output(DAQOutput(dq, 'port0/line0'), 'SI Trigger'),...
    Input(DAQInput(dq, 'ai0'), 'SI Frame'));

holo = HoloComputer();

fpc_900 = FiberPowerControl(Output(DAQOutput(dq, 'port0/line5'), 'Shutter 900'),...
    ELL14(SerialInterface(sp), 1, 'Power 900'),...
    power_calibration.calibration_900, 250); % update these calibration paths as you get them...

fpc_1100 = FiberPowerControl(Output(DAQOutput(dq, 'port0/line4'), 'Shutter 1100'),...
    ELL14(SerialInterface(sp), 2, 'Power 1100'),...
    power_calibration.calibration_1100, 250);


slm_900 = SLMComm(Output(DAQOutput(dq, 'port0/line2'), 'SLM Trigger'),...
    Input(DAQInput(dq, 'ai1'), 'SLM FLip'));

slm_1100 = SLMComm(Output(DAQOutput(dq, 'port0/line3'), 'SLM Trigger2'),...
    Input(DAQInput(dq, 'ai2'), 'SLM FLip2')); 

patch = Patch(Output(DAQOutput(dq, 'ao0'), 'patch output'),... 
    Input(DAQInput(dq, 'ai7'), 'patch input'));

% rwheel = RunningWheel(); % add running wheel here

tm.modules.add(si);
tm.modules.add(holo);
tm.modules.add(slm_900);
tm.modules.add(slm_1100);
tm.modules.add(fpc_900);
tm.modules.add(fpc_1100);
tm.modules.add(patch);


% 
% %% below is holography setup
% pause(0.5)
% holoRequest = importdata(fullfile(loc.HoloRequest, 'holoRequest.mat'));
% 
% holoRequest.rois = {1:size(holoRequest.targets, 1)};%makeseq(holoRequest);
% % eventually some kind of code that gathers them, rigth now one at a time?
% 
% % overlapping cells
% holo.transferHR(holoRequest);
% holo.transferHR(holoRequest);
 sm.start_session();

%%
n_trials = 5;
red_power = 0.01;
scale = 2;

% randomly sample powers...
clear stims
for n = 1:n_trials
    stims{1, n} = StimInfo(1, 1, red_power, 1000, 20);
    stims{2, n} = StimInfo(1, 1, red_power*scale, 1000, 20);
end

% lastly, need to get info about stimulus
 %%
disp('Press any key to continue...')
pause
ct = 1;

start_delay = 500; % 500ms delay from start imaging for stim
for p = 1:n_trials
    disp(ct)
    tic; 
    s = [stims{:, p}];
    
    patch.control.set(randi(3, [30000, 1]));
    % determine overall trial length
    % trial_length = max([s(1).trial_length, s(2).trial_length]);
    trial_length = 1000 + start_delay;
    tm.set_trial_length(trial_length); % stimulus on
    fprintf('This trial duration is %ds\n', trial_length/1000)
    fprintf('Red power: %0.02fmW | Blue power: %0.02fmW\n', s(1).power*1000, s(2).power*1000)
    % optogenetic params
    fpc_1100.set_power(s(1).power); % rigth now, power can only be a single value throughout the trial... we don't have the ability to trigger changes (yet)
    if s(1).power > 0
        for ii = 1:s.N % number of holos?
            fpc_1100.set_shutter(s(1).pulse_duration(ii), s(1).total_stimulation_time(ii), s(1).hz(ii), start_delay + sum(s(1).total_stimulation_time(1:ii-1)))
        end
    end

    % optogenetic params

    fpc_900.set_power(s(2).power); % rigth now, power can only be a single value throughout the trial... we don't have the ability to trigger changes (yet)
    if s(2).power > 0
        for ii = 1:s.N % number of holos?
            fpc_900.set_shutter(s(2).pulse_duration(ii), s(2).total_stimulation_time(ii), s(2).hz(ii), start_delay + sum(s(2).total_stimulation_time(1:ii-1)))
        end
    end

    % set SLM stuff?
    for ii = 1:s.N
        slm_1100.set_flip(sum(s(1).total_stimulation_time(1:ii-1))+1);
        slm_900.set_flip(sum(s(2).total_stimulation_time(1:ii-1))+1);
    end

    % prepare machinery
    holo.set_sequence({s.firing_order}); % sequenc is a cell array for multislm

    % run the trial
    out = tm.run_trial();
    sm.saver.store(out);
    toc
    ct = ct + 1;
end
%%
sm.end_session();
fprintf('All done and saved!\n')
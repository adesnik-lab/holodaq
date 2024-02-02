%% TO DO

clear
close all
clc

%% SET LASER POWERS HERE??
rb_scale = 3; % too much power bad... 3.5; % what is the scale between red and blue?
pwr_scale = [0, 0.5, 1]; % multiplier above baseline?

red_powers = 2/1000;%
blue_powers = red_powers * rb_scale;

n_trials = 800;

%%
default_setup();
tm = TrialManager(dq);
sm = SessionManager(tm, 'patch');

%% Modules
si = SIComputer(Output(DAQOutput(dq, 'port0/line0'), 'SI Trigger'),...
    Input(DAQInput(dq, 'ai0'), 'SI Frame'));

fpc_900 = FiberPowerControl(Output(DAQOutput(dq, 'port0/line5'), 'Shutter 900'),...
    ELL14(SerialInterface(sp), 1, 'Power 900'),...
    power_calibration.calibration_900, 250); % update these calibration paths as you get them...

fpc_1100 = FiberPowerControl(Output(DAQOutput(dq, 'port0/line4'), 'Shutter 1100'),...
    ELL14(SerialInterface(sp), 2, 'Power 1100'),...
    power_calibration.calibration_1100, 250);

patch = PatchInput(); % idr what its called... move the stupid things to 
tm.modules.add(si);
tm.modules.add(fpc_900);
tm.modules.add(fpc_1100);

% %% below is holography setup
% holoRequest = importdata(fullfile(loc.HoloRequest, 'holoRequest.mat'));
% 
% holoRequest.rois = {1:size(holoRequest.targets, 1)};%makeseq(holoRequest);
% % eventually some kind of code that gathers them, rigth now one at a time?
% % for 900
% holoRequest.zRemapping = []; % kill it
% holo.transferHR(holoRequest);
% % for 1100 (same ROIs)
% holo.transferHR(holoRequest);
%%
%power
clear rstim_pool bstim_pool
ct = 1;
for ii = 1:length(red_powers)
    for p = pwr_scale
        rstim_pool(ct) = StimInfo(ii, 1, red_powers(ii) * p, 1000, 990); % 500ms on?
        bstim_pool(ct) = StimInfo(ii, 1, blue_powers(ii) * p, 1000, 990);
        ct = ct + 1;
    end
end

% randomly sample powers...
clear stims
for n = 1:n_trials
    stims{1, n} = rstim_pool(randi(length(rstim_pool)));
    stims{2, n} = bstim_pool(randi(length(bstim_pool)));
end

% lastly, need to get info about stimulus
vis_stim = randi(5, n_trials, 1);
stim_struct = cellfun(@struct, stims);
sm.saver.add(stim_struct, 'stim');
sm.saver.add(vis_stim, 'vis_stim');
%% here
sm.start_session();

%%
fprintf('Press any key to continue:\n')
pause
% ptb.controller.send('go');
ptb.go()
ct = 1;

warning('MANUALLY SCALING FOR ND0.3 FILTER')
start_delay = 500; % 500ms delay from start imaging for visual and other stim
for p = 1:n_trials
    t = tic;
    s = [stims{:, p}];
    
    trial_length = 1000 + start_delay; % reduced to account for the lag
    tm.set_trial_length(trial_length); % stimulus on
    % fprintf('This trial duration is %ds\n', trial_length/1000)
    fprintf('----------------------\nTrial %d/%d\n', p, n_trials)
    fprintf('Red power: %0.02fmW | Blue power: %0.02fmW\n', s(1).power*1000, s(2).power*1000)
    % optogenetic params
    fpc_1100.set_power(s(1).power); % rigth now, power can only be a single value throughout the trial... we don't have the ability to trigger changes (yet)
    if s(1).power > 0
        for ii = 1:s.N % number of holos?
            fpc_1100.set_shutter(s(1).pulse_duration(ii), s(1).total_stimulation_time(ii), s(1).hz(ii), start_delay + sum(s(1).total_stimulation_time(1:ii-1)))
        end
    end

    % optogenetic params
    fpc_900.set_power(s(2).power*2); % rigth now, power can only be a single value throughout the trial... we don't have the ability to trigger changes (yet)
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
    ptb.send_stim_idx(vis_stim(p));
    ptb.set_delay(start_delay);
    % run the trial

    trial_data = tm.run_trial();
    sm.saver.store(trial_data); 
    toc(t) 
    ct = ct + 1;
end

%% save stim info
sm.end_session();

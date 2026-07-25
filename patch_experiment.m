% TO DO

clear
close all
clc

% PARAMS

%
default_setup();
tm = TrialManager(dq);
sm = SessionManager(tm, 'bleh');

% Modules (wiring comes from the rig file loaded by default_setup; a rig
% without a module skips it)
if rig_has(rig, 'si')
    c = rig.modules.si;
    si = SIComputer(Output(DAQOutput(dq, c.trigger), 'SI Trigger'),...
        Input(DAQInput(dq, c.frame), 'SI Frame'));
    tm.modules.add(si);
end

if rig_has(rig, 'holo')
    holo = HoloComputer();
    tm.modules.add(holo);
end

if rig_has(rig, 'fpc_900')
    c = rig.modules.fpc_900;
    fpc_900 = FiberPowerControl(Output(DAQOutput(dq, c.shutter), 'Shutter 900'),...
        ELL14(SerialInterface(sp), c.ell14_channel, 'Power 900'),...
        c.calibration, c.khz);
    tm.modules.add(fpc_900);
end

if rig_has(rig, 'fpc_1100')
    c = rig.modules.fpc_1100;
    fpc_1100 = FiberPowerControl(Output(DAQOutput(dq, c.shutter), 'Shutter 1100'),...
        ELL14(SerialInterface(sp), c.ell14_channel, 'Power 1100'),...
        c.calibration, c.khz);
    tm.modules.add(fpc_1100);
end

if rig_has(rig, 'slm_900')
    c = rig.modules.slm_900;
    slm_900 = SLMComm(Output(DAQOutput(dq, c.trigger), 'SLM Trigger'),...
        Input(DAQInput(dq, c.flip), 'SLM FLip'));
    tm.modules.add(slm_900);
end

if rig_has(rig, 'slm_1100')
    c = rig.modules.slm_1100;
    slm_1100 = SLMComm(Output(DAQOutput(dq, c.trigger), 'SLM Trigger2'),...
        Input(DAQInput(dq, c.flip), 'SLM FLip2'));
    tm.modules.add(slm_1100);
end

if rig_has(rig, 'patch')
    c = rig.modules.patch;
    patch = Patch(Output(DAQOutput(dq, c.output), 'patch output'),...
        Input(DAQInput(dq, c.input), 'patch input'));
    tm.modules.add(patch);
end

if rig_has(rig, 'wheel')
    rwheel = RunningWheel(); % add running wheel here
end

 sm.start_session();

%
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
 %
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
    trial_length = max([s(1).trial_length, s(2).trial_length]);
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
%
sm.end_session();
fprintf('All done and saved!\n')

%% TO DO
% msocket control? should that happen here or somewhere else?
% big calls on some things
% gotta append the data or else it's just going to keep writing bigger and
% bigger, and there's no benefit there, we want it to save in the middle,
% right?

% change wait timeout


% can we combine the daq somehow?

% bugfixes
% add checknig for trial length vs actual sweep

clear
close all
clc

addpath(genpath('.'))
addpath(genpath('C:\Users\holos\Documents\_code'))

fprintf('Starting daq...\r')

fprintf('Loading defaults... ')
setup = getDefaults();  
pause(0.1)
fprintf('OK.\n')

fprintf('Making MATLAB NIDAQ object... ')
dq = daq('ni');
dq.Rate = setup.daqrate;
pause(0.1)
fprintf('OK.\n')

tman = TrialManager(dq);

%% Modules
si = SIComputer(Output(DAQOutput(dq, 'port0/line0'), 'SI Trigger'),...
                Input(DAQInput(dq, 'ai0'), 'SI Frame'));

ptb = PTBComputer(Output(DAQOutput(dq, 'port0/line1'), 'PTB Trigger'),...
                  Input(DAQInput(dq, 'port0/line15'), 'Stim ONOFF'),...
                  Input(DAQInput(dq, 'port0/line13'), 'Stim ID'));

rwheel = RunningWheel(Input(DAQInput(dq, 'ai2'), 'Running Wheel'));

laser_eom = LaserEOM(Output(DAQOutput(dq, 'ao0'), 'Laser Trigger'));

slm = SLM(Output(DAQOutput(dq, 'ao1'), 'SLM Trigger'),...
          Input(DAQInput(dq, 'ai1'), 'SLM FLip'));

tman.modules.add(si);
tman.modules.add(ptb); 
tman.modules.add(slm);
tman.modules.add(laser_eom);
tman.modules.add(rwheel);

%% saving
tman.set_save_path('D:\data\test.mat');
tman.initialize(); % initialize all added modules

%% Select code?
holosToUse = importdata('holosToUse.mat');

%% Generate triggers?
load('HoloRequest.mat') % replace later with appropriate holorequest get function

powers = [0.1, 0.01];
trial_lengths = [2000, 2000];

ct = 1;

for p = powers(1); %repmat(powers(1:2), 1, )
    disp(ct)
    ts = tic;
    % this section takes ~0.04s, probably not worth worryngi about
    % [maxSeqDur, holoRequest] =  getPTestStimParamsKS(holoRequest, p);
    tman.set_trial_length(3000);
    Makefixedspike2k % takes care of laser_eom and slm triggers
    % si.info.set('hello');
    si.trigger.set([1, 25, 1]);
    ptb.trigger.set([1, 25, 1]);
    tman.prepare()
    
    ts2 = tic;
    tman.start_trial();
    tman.end_trial();


    % tman.do_stuff(); % we can run stuff in the ITI, but be careful, if the thing you run is too long, it might delay the next call
    t2 = toc(ts);
    t1 = toc(ts2);
    % fprintf('Trial duration: %0.05f\n', t1);
    fprintf('Total: %0.05f\n', t1)
    fprintf('ITI: %0.05f\n', t2);    
    ct = ct + 1;
end
% obj.saver.save('all');


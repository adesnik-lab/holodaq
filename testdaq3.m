%% TO DO
% msocket control? should that happen here or somewhere else?
% big calls on some things
% gotta append the data or else it's just going to keep writing bigger and
% bigger, and there's no benefit there, we want it to save in the middle,
% right?

% change wait timeout


% bugfixes
% add checknig for trial length vs actual sweep

clear
close all
clc

addpath(genpath('.'))


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
si = SIComputer(dq, 'port0/line0', 'ai0');
ptb = PTBComputer(dq, 'port0/line1', 'port0/line15', 'port0/line13');
rwheel = RunningWheel(dq, 'ai2');
laser_eom = LaserEOM(dq, 'ao0');
slm = SLM(dq, 'ao1', 'ai1'); % this is overkill for the SLM trigger, but I just don't want loose cables lol (see the daq, this lets me keep bnc for everything)

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

for p = repmat(powers(1:2), 1, 10)
    disp(ct)
    ts = tic;
    % this section takes ~0.04s, probably not worth worryngi about
    % [maxSeqDur, holoRequest] =  getPTestStimParamsKS(holoRequest, p);
    tman.set_trial_length(3000+randi(200) - 100);
    Makefixedspike2k % takes care of laser_eom and slm triggers
    
    % si.info.set('hello');
    si.trigger.set([1, 25, 1]);
    ptb.trigger.set([1, 25, 1]);
    tman.prepare();
    
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

tman.do_stuff(); % make sure the last one is saved
%% TO DO
% msocket control? should that happen here or somewhere else?
% can we combine the daq somehow?

% bugfixes
% add checknig for trial length vs actual sweep

clear
close all
clc

%% PARAMS
n_trials = 300;
save_path = 'D:\data\test3.mat';

%%
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

ptb = PTBComputer(Output(DAQOutput(dq, 'port0/line7'), 'PTB Trigger'),...
                  Input(DAQInput(dq, 'port0/line2'), 'Stim ONOFF'),...
                  Input(DAQInput(dq, 'port0/line3'), 'Stim ID'));

tman.modules.add(si);
tman.modules.add(ptb); 

fprintf('Initializing DAQ... ')
tman.set_save_path(save_path);
tman.initialize(); % initialize all added modules
fprintf('OK.\n')

%%

ct = 1;

disp('Press any key to start...')
pause
for p = 1:n_trials
    disp(ct)
    tic;
    tman.set_trial_length(2000);
    
    si.trigger.set([1, 25, 1]);             
    ptb.trigger.set([1, 25, 1]);
    
    tman.prepare();

    tman.start_trial();


    tman.end_trial();
    toc
    ct = ct + 1;
end


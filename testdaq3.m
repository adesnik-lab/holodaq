clear
close all
clc

addpath(genpath('.'))

fprintf('Starting daq...\r')

fprintf('Loading defaults... ')
setup = getDefaults();
pause(0.5)
fprintf('OK.\n')

fprintf('Making MATLAB NIDAQ object... ')
% dq = daq('ni');
dq = fakedaq();
dq.Rate = setup.daqrate;
pause(0.5)
fprintf('OK.\n')

tm = TrialManager(dq);

%% reduce copies of the daq

%% OUTPUTS
tm.modules.add(ScanImageTrigger(dq, 'port0/line0'));
tm.modules.add(LaserEOM(dq, 'ao0'));

%% INPUTS
tm.modules.add(SLMFlip(dq, 'ai0'));

tm.initialize();
tm.set_trial_length(550); %in ms

tm.modules.ScanImageTrigger.controller.set_trigger(100, 50); % in ms
tm.modules.LaserEOM.controller.set_trigger([100:100:500], 50);

% for one trial
%%%
tm.prepare()

tm.show();

tm.start()

for t = 1:n_trials
    tm.prepare()
    tm.start()
end
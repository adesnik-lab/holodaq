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
sim = ScanImageTrigger(dq, 'port0/line0');
ptb = PsychToolboxTrigger(dq, 'port0/line1');
tm.modules.add(sim);
tm.modules.add(ptb);
tm.modules.add(LaserEOM(dq, 'ao0'));

%% INPUTS
tm.modules.add(SLMFlip(dq, 'ai0'));

tm.initialize();

%%

tm.set_trial_length(550); %in ms

sim.trigger.set_trigger(200, 50); % in ms, trigger failure here
ptb.trigger.set_trigger(1, 10);
tm.modules.LaserEOM.trigger.set_trigger([100:100:300], 50);

% for one trial
%%%
tm.prepare()

tm.show();

tm.start()

for t = 1:n_trials
    tm.prepare()
    tm.start()
end
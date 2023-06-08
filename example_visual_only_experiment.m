clear
close all
clc

addpath(genpath('.'))

%% this could probably be put into a function or something?
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

%%
metadata = generateMetadataStruct(); % default stuff, like machine configuration info, etc?
metadata.mouseID = 'KKS002-1';
metadata.date = '230216';

tm = TrialManager(dq);

sim = ScanImageTrigger(dq, 'port0/line0');
ptb = PsychToolboxTrigger(dq, 'port0/line1');
slm = SLMTrigger(dq, 'port0/line2');
% not yet implemented
% stimIDSender = StimSender('something?');
tm.modules.add(sim);
tm.modules.add(ptb);
tm.initialize();

%%
n_trials = 500;
% uneven trial lengths
trial_lengths = randi(100, 1, n_trials);
ptb_trigger_times = rand(1, n_trials);
stim_ids = randi(20, n_trials); % or however you want to generate this here

sim.trigger.set_trigger(200, 50); % in ms, trigger failure here

% for one trial
%%%

for t = 1:n_trials
    ptb.trigger.set_trigger(ptb_trigger_times(t));
    tm.set_trial_length(trial_lengths(t));

    tm.prepare()
    tm.start()
end

% cleanup here?
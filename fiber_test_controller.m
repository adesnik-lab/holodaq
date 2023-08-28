%% TO DO
% msocket control? should that happen here or somewhere else?
% can we combine the daq somehow?

% bugfixes
% add checknig for trial length vs actual sweep

%% Clean workspace
clear
close all
clc
addpath(genpath('.'))
addpath(genpath('C:\Users\holos\Documents\_code'))

%%
fprintf('Starting daq...\r')

fprintf('Loading defaults... ')
setup = getDefaults();  
fprintf('OK.\n')

fprintf('Making MATLAB NIDAQ object... ')
dq = daq('ni');
dq.Rate = setup.daqrate;
fprintf('OK.\n')
tman = TrialManager(dq);

output_laser_900 = Output(DAQOutput(dq, 'port0/line5'), '900 Laser');
output_laser_1100 = Output(DAQOutput(dq, 'port0/line6'), '1100 Laser');
si_trigger = Output(DAQOutput(dq, 'port0/line0'), 'SI Trigger');

ft = FiberTester(output_laser_900, output_laser_1100, si_trigger, laser_eom);

tman.modules.add(ft);
tman.set_save_path('test')

% Initialize modules
tman.initialize(); % initialize all added modules


%% Set Parameters
freq = 10; %hz
msec_on = 10; %ms
stim_duration = 1000; %ms
imaging_duration = 2000; %ms
asynchronous = true;

%% Calculate Additional Parameters
msec_off = 1000/freq - msec_on;

if msec_off < 0
    error('Pulse too long for frequency')
end

if asynchronous
    trial_duration = stim_duration + imaging_duration;
else
    trial_duration = max(stim_duration, stim_duration);
end
%% Generate triggers?
ct = 1;

for p = 1:n_trials
  
    tman.set_trial_length(trial_duration);

    si.trigger.set([1, 25, 1]); % trigger the start of the trial
    
    tman.prepare();

    tman.start_trial(); 

    tman.end_trial();
end


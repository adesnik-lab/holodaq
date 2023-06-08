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

%%outputs
addAnalogOutputChannel(s,'Dev1',2,'Voltage'); %LASER EOM
addDigitalChannel(s,'Dev1','port0/Line0', 'OutputOnly'); %si trig
addDigitalChannel(s,'Dev1','port0/Line2', 'OutputOnly'); %slm trig
addDigitalChannel(s,'Dev1','port0/Line3', 'OutputOnly'); %pt trig


%%inputs
addDigitalChannel(s, 'Dev1','port0/line15','InputOnly'); %pt vis stim on/off
addDigitalChannel(s, 'Dev1','port0/line13','InputOnly'); %pt stim id signal
addDigitalChannel(s, 'Dev1','port0/line10','InputOnly'); %running


%% OUTPUTS
sim = ScanImageTrigger(dq, 'port0/line0');
ptb = PsychToolboxTrigger(dq, 'port0/line1');
laser_eom = LaserEOM(dq, 'ao0');
slm = SLMTrigger(dq, 'port0/line2');

tm.modules.add(sim);
tm.modules.add(ptb); 
tm.modules.add(slm);
tm.modules.add(laser_eom);

%% INPUTS
pt_input = PsychToolboxReporter();
pt_stim_id = PsychToolboxStimID();
running_input = RunningInput();
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
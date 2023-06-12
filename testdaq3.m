%% TO DO
% work on getting inputs in place
% msocket control? should that happen here or somewhere else?
% data saving
% saver into reader
% big calls on some things
% can we reduce delay via background running


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
pause(0.5)
fprintf('OK.\n')

fprintf('Making MATLAB NIDAQ object... ')
dq = daq('ni');
% dq = fakedaq();
dq.Rate = setup.daqrate;
pause(0.5)
fprintf('OK.\n')

tman = TrialManager(dq);

%% reduce copies of the daq
%{
%%outputs
addAnalogOutputChannel(dq,'Dev1',2,'Voltage'); %LASER EOM
addDigitalChannel(dq,'Dev1','port0/Line0', 'OutputOnly'); %si trig
addDigitalChannel(dq,'Dev1','port0/Line2', 'OutputOnly'); %slm trig
addDigitalChannel(dq,'Dev1','port0/Line3', 'OutputOnly'); %pt trig


%%inputs
addDigitalChannel(dq, 'Dev1','port0/line15','InputOnly'); %pt vis stim on/off
addDigitalChannel(dq, 'Dev1','port0/line13','InputOnly'); %pt stim id signal
addDigitalChannel(dq, 'Dev1','port0/line10','InputOnly'); %running
%}

%% OUTPUTS
si = SIComputer(dq, 'port0/line0', 'ai0');
ptb = PTBComputer(dq, 'port0/line1', 'port0/line15', 'port0/line13');

% running input
rwheel = RunningWheel(dq, 'ai2');
laser_eom = LaserEOM(dq, 'ao0');
slm = SLM(dq, 'ao1', 'ai1'); % this is overkill for the SLM trigger, but I just don't want loose cables lol (see the daq, this lets me keep bnc for everything)
 
tman.modules.add(si);
tman.modules.add(ptb); 
tman.modules.add(slm);
tman.modules.add(laser_eom);
tman.modules.add(rwheel);

%% INPUTS
%{
pt_input = PsychToolboxReporter();
pt_stim_id = PsychToolboxStimID();
running_input = RunningInput();
tman.modules.add(SLMFlip(dq, 'ai0'));
%}

tman.initialize();


%% Select code?
holosToUse = importdata('holosToUse.mat');

%% Generate triggers?
load('HoloRequest.mat') % replace later with appropriate holorequest get function

powers = [0.1, 0.01];
trial_scaling = [1, 1.2];
trial_lengths = [3000, 5000];
ct = 1;
for p = powers(1:2)
    
    % [maxSeqDur, holoRequest] =  getPTestStimParamsKS(holoRequest, p);
    tman.set_trial_length(trial_lengths(ct));
    Makefixedspike2k % takes care of laser_eom and slm triggers
    
    si.info.set('hello');
    si.trigger.set([1, 25, 1]);
    ptb.trigger.set([1, 25, 1]);
    % Prepare and show
    tman.prepare();
    t2 = toc;

    % tman.show();
    tic
    tman.start_trial();
    
    tman.end_trial();

    fprintf('Trial duration: %0.05f\n', t1);
    fprintf('ITI: %0.05f\n', t2);    
    ct = ct + 1;
end
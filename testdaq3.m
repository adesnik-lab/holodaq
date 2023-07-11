%% TO DO
% msocket control? should that happen here or somewhere else?
% can we combine the daq somehow?

% bugfixes
% add checknig for trial length vs actual sweep

clear
close all
clc

<<<<<<< Updated upstream
=======

% PARAMS
holography = true;
power = 0.075; % W
n_trials = 10;

>>>>>>> Stashed changes
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
                  Input(DAQInput(dq, 'port0/line2'), 'Stim ONOFF'),...
                  Input(DAQInput(dq, 'port0/line3'), 'Stim ID'));

rwheel = RunningWheel(Input(DAQInput(dq, 'ai2'), 'Running Wheel'));

laser_eom = LaserEOM(Output(DAQOutput(dq, 'ao0'), 'Laser Trigger'));

slm = SLM(Output(DAQOutput(dq, 'ao1'), 'SLM Trigger'),...
          Input(DAQInput(dq, 'ai1'), 'SLM FLip'));

tman.modules.add(si);
tman.modules.add(ptb); 
tman.modules.add(slm);
tman.modules.add(laser_eom);
tman.modules.add(rwheel);

fprintf('Initializing DAQ... ')
tman.set_save_path('D:\data\test.mat');
tman.initialize(); % initialize all added modules
fprintf('OK.\n')

%% Select code?
loc = FrankenScopeRigFile();
holoRequest = importdata(sprintf('%s%sholoRequest.mat', loc.HoloRequest, filesep));
% holosToUse = importdata('holosToUse.mat');

MakePowerCurveOutput2K();
%% Generate triggers?
% load('HoloRequest.mat') % replace later with appropriate holorequest get function

powers = [0.1, 0.01];
trial_lengths = [2000, 2000];

ct = 1;

<<<<<<< Updated upstream
for p = 1;%repmat(powers(1:2), 1, 1)
=======
n_trials = 100;
for p = 1:n_trials;%repmat(powers(1:2), 1, 1)
    % if mod(p, 2) == 1
    %     holography = true;
    % else 
    %     holography = false;
    % end

>>>>>>> Stashed changes
    disp(ct)
    ts = tic;
    % this section takes ~0.04s, probably not worth worryngi about
    % [maxSeqDur, holoRequest] =  getPTestStimParamsKS(holoRequest, p);
    tman.set_trial_length((maxSeqDur+1) * 1000  + randi(200));
    % Makefixedspike2k % takes care of laser_eom and slm triggers
    % si.info.set('hello');
    makeHoloTrigSeqs2K(Seq, holoRequest, slm, laser_eom); % here,  we can choose what Seq to send by indexing into it
    si.trigger.set([1, 25, 1]);             
    ptb.trigger.set([1, 25, 1]);
    % tman.prepare_old()
    
    tman.prepare();

    ts2 = tic;
    tman.start_trial();
    
    mssend(holoSocket, Seq{1});
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


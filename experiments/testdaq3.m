%% TO DO
% msocket control? should that happen here or somewhere else?
% can we combine the daq somehow?

% bugfixes
% add checknig for trial length vs actual sweep

clear
close all
clc

% PARAMS
holography = true;
power = 0.040; % W
n_trials = 10;

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
                Input(DAQInput(dq, 'ai0'), 'SI Frame'));%,... is it worth it here to make a contrnoller?
                %SIController(MSocketInterface(ip, port)));

ptb = PTBComputer(Output(DAQOutput(dq, 'port0/line7'), 'PTB Trigger'),...
                  Input(DAQInput(dq, 'port0/line2'), 'Stim ONOFF'),...
                  Input(DAQInput(dq, 'port0/line3'), 'Stim ID'));

rwheel = RunningWheel(Input(DAQInput(dq, 'ai2'), 'Running Wheel'));

laser_eom = LaserEOM(Output(DAQOutput(dq, 'ao0'), 'Laser Trigger'));
% 
slm = SLM(Output(DAQOutput(dq, 'ao1'), 'SLM Trigger'),...
          Input(DAQInput(dq, 'ai1'), 'SLM FLip'));

% slm = SLM(Output(DAQOutput(dq, 'port0/line6'), 'SLM Trigger'),...
%           Input(DAQInput(dq, 'ai7'), 'SLM FLip'));


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
if holography
    loc = FrankenScopeRigFile();
    holoRequest = importdata(sprintf('%s%sholoRequest.mat', loc.HoloRequest, filesep));
    % holosToUse = importdata('holosToUse.mat');
    fs = FixedSeq(holoRequest, power);
    holoSocket = fs.run();
    
% MakePowerCurveOutput2K();
end



disp('Press any key when holography computer is finished...')
pause

%% Generate triggers?
% load('HoloRequest.mat') % replace later with appropriate holorequest get function


ct = 1;

n_trials = 25;
for p = 1:n_trials
    disp(ct)
    ts = tic;

    if holography
        tman.set_trial_length((fs.getMaxSeqDur()+1) * 1000);
    else
        tman.set_trial_length(5000);
    end

    if holography
        % makeHoloTrigSeqs2K(Seq, holoRequest, slm, laser_eom); % here,  we can choose what Seq to send by indexing into it
        Seq = fs.makeHoloSequences();
        makeHoloTrigSeqs2K(Seq, fs, slm, laser_eom); % here,  we can choose what Seq to send by indexing into it
    end
    si.trigger.set([1, 25, 1]);             
    ptb.trigger.set([1, 25, 1]);
    
    tman.prepare();

    ts2 = tic;
    tman.start_trial();
    
    if holography
        mssend(holoSocket, Seq{1});
    end

    tman.end_trial();

    t2 = toc(ts);

    t1 = toc(ts2);
    fprintf('Total: %0.05f\n', t1)
    fprintf('ITI: %0.05f\n', t2);    
    ct = ct + 1;
end


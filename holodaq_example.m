%% TO DO
% msocket control? should that happen here or somewhere else?
% can we combine the daq somehow?

% bugfixes
% add checknig for trial length vs actual sweep

clear
close all
clc

% PARAMS
holography = false;
power = 0.075; % W

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

%% PARAMS
mouse = 'KKSTEST-2';
epoch = '1ori';
n_trials = 10;
save_path = 'D:\data\test3.mat';

% These persist through all controllers
%% Modules
si = SIComputer(Output(DAQOutput(dq, 'port0/line0'), 'SI Trigger'),...
                Input(DAQInput(dq, 'ai0'), 'SI Frame'), ...
                SIController(MSocketServer(42045), 'SI Controller'));

ptb = PTBComputer(Output(DAQOutput(dq, 'port0/line7'), 'PTB Trigger'),...
                  Input(DAQInput(dq, 'port0/line2'), 'Stim ONOFF'),...
                  Input(DAQInput(dq, 'port0/line3'), 'Stim ID'), ...
                  PTBController(MSocketServer(42044), 'PTB Controller'));

holo = HoloComputer(HoloController(MSocketServer(42041), 'Holo Controller'));

rwheel = RunningWheel(Input(DAQInput(dq, 'ai2'), 'Running Wheel'));

laser_eom = LaserEOM(Output(DAQOutput(dq, 'ao0'), 'Laser Trigger'));

slm = SLM(Output(DAQOutput(dq, 'ao1'), 'SLM Trigger'),...
          Input(DAQInput(dq, 'ai1'), 'SLM FLip'));

tman.modules.add(si);
% tman.modules.add(ptb); 
% tman.modules.add(holo);
tman.modules.add(rwheel);
tman.modules.add(laser_eom);

tman.set_save_path(save_path);
tman.initialize(); % initialize all added modules
fprintf('All done.\n')

%% Set stuff
tman.set_mouse(mouse);
tman.set_epoch(epoch);

%% Select code?
if holography
    loc = FrankenScopeRigFile();
    holoRequest = importdata(sprintf('%s%sholoRequest.mat', loc.HoloRequest, filesep));
    % holosToUse = importdata('holosToUse.mat');
    fs = FixedSeq(holoRequest, power);
    fs.run();
    holo.controller.run();
    fs.holoRequest = transferHRNoDAQ(fs.holoRequest, holo.controller.io.socket);
end

ptb.controller.run_stimulus('basic_ori_trigger');
si.controller.prepare(true);
si.controller.start();
%% Generate triggers?
ct = 1;

n_trials = 5;
for p = 1:n_trials;%repmat(powers(1:2), 1, 1)
    disp(ct)
    ts = tic;

    if holography
        tman.set_trial_length((fs.getMaxSeqDur()+1) * 1000);
    else
        tman.set_trial_length(5000);
    end

    if holography
        Seq = fs.makeHoloSequences();
        makeHoloTrigSeqs2K(Seq, fs, slm, laser_eom); % here,  we can choose what Seq to send by indexing into it
    end
    si.trigger.set([1, 25, 1]);             
    ptb.trigger.set([1, 25, 1]);
    
    tman.prepare();

    ts2 = tic;
    tman.start_trial();
    
    if holography
        holo.controller.io.send(Seq{1})
    end

    tman.end_trial();


    t2 = toc(ts);

    t1 = toc(ts2);
    fprintf('Total: %0.05f\n', t1)
    fprintf('ITI: %0.05f\n', t2);    
    ct = ct + 1;
end


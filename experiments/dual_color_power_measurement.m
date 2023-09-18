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

%% PARAMS
holography = false;
power = 0.075; % W
mouse = 'KKSTEST-2';
epoch = '1ori';
save_path = 'D:\data\test3.mat';
stimulus = 'basic_ori_trigger';
n_trials = 5;

%%
fprintf('Starting daq...\r')

fprintf('Loading defaults... ')
setup = getDefaults();  
fprintf('OK.\n')

fprintf('Making MATLAB NIDAQ object... ')
dq = daq('ni');
dq.Rate = setup.daqrate;
fprintf('OK.\n')

fprintf('Making SerialPort object... ')
s = serialport("COM5", ...
    9600,...
    'ByteOrder', 'big-endian',...
    'Parity', 'none',...
    'StopBits', 1,...
    'DataBits', 8);
s.configureTerminator('CR/LF');
fprintf('OK.\n')


tman = TrialManager(dq);

si = SIComputer(Output(DAQOutput(dq, 'port0/line0'), 'SI Trigger'),...
                Input(DAQInput(dq, 'ai0'), 'SI Frame'), ...
                SIController(MSocketServer(42045), 'SI Controller'));

ptb = PTBComputer(Output(DAQOutput(dq, 'port0/line7'), 'PTB Trigger'),...
                  Input(DAQInput(dq, 'port0/line2'), 'Stim ONOFF'),...
                  Input(DAQInput(dq, 'port0/line3'), 'Stim ID'), ...
                  PTBController(MSocketServer(42044), 'PTB Controller'));

fpc_900 = FiberPowerControl(Output(DAQOutput(dq, 'port0/line5'), 'Shutter 900'),...
                            ELL14(SerialInterface(s), 0, 'Power 900'),...
                            'C:\Users\holos\Documents\power-calibrations\230918_900nm_100kHz_25AOM_fast_gate_calibration.mat');

fpc_900 = FiberPowerControl(Output(DAQOutput(dq, 'port0/line6'), 'Shutter 1100'),...
                            ELL14(SerialInterface(s), 0, 'Power 1100'),...
                            'C:\Users\holos\Documents\power-calibrations\230918_1100nm_100kHz_25AOM_fast_gate_calibration.mat');

holo = HoloComputer(HoloController(MSocketServer(42042), 'Holo Controller'));

% rwheel = RunningWheel(Input(DAQInput(dq, 'ai2'), 'Running Wheel'));

% laser_eom = LaserEOM(Output(DAQOutput(dq, 'ao0'), 'Laser Trigger'));
% 
% slm = SLM(Output(DAQOutput(dq, 'ao1'), 'SLM Trigger'),...
%           Input(DAQInput(dq, 'ai1'), 'SLM FLip'));

tman.modules.add(si);
tman.modules.add(ptb); 
tman.modules.add(holo);
tman.modules.add(rwheel);
tman.modules.add(laser_eom);
tman.set_save_path(save_path);

% Initialize modules
tman.initialize(); % initialize all added modules
tman.set_mouse(mouse);
tman.set_epoch(epoch);
fprintf('All done.\n')

%% Select code?
if holography
    loc = FrankenScopeRigFile();
    holoRequest = importdata(fullfile(loc.HoloRequest, 'holoRequest.mat'));
    fs = PowerCurve(holoRequest, power);
    fs.run();
    holo.controller.run();
    fs.holoRequest = transferHRNoDAQ(fs.holoRequest, holo.controller.io.socket);
end

ptb.controller.run_stimulus(stimulus); % choose your stimulus here?
si.controller.prepare(true); % ask for triggering
si.controller.start();

%% Generate triggers?
ct = 1;

for p = 1:n_trials
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
    si.trigger.set([1, 25, 1]); % trigger the start of the trial
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


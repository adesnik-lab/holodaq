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
mouse = 'KKS010-2';
epoch = '1ori';
save_path = 'D:\data\test3.mat';
stimulus = 'basic_ori_trigger';
n_trials = 1000;

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
                Input(DAQInput(dq, 'ai0'), 'SI Frame'), []);% ...
             %   SIController(MSocketServer(42045), 'SI Controller'));

ptb = PTBComputer(Output(DAQOutput(dq, 'port0/line7'), 'PTB Trigger'),...
                  Input(DAQInput(dq, 'port0/line2'), 'Stim ONOFF'),...
                  Input(DAQInput(dq, 'port0/line3'), 'Stim ID'), []);%...
                %  PTBController(MSocketServer(42044), 'PTB Controller'));

fpc_900 = FiberPowerControl(Output(DAQOutput(dq, 'port0/line5'), 'Shutter 900'),...
                            ELL14(SerialInterface(s), 0, 'Power 900'),...
                            'C:\Users\holos\Documents\power-calibrations\230920_900nm_500kHz_25AOM_uni_gate_calibration.mat');

fpc_1100 = FiberPowerControl(Output(DAQOutput(dq, 'port0/line6'), 'Shutter 1100'),...
                            ELL14(SerialInterface(s), 1, 'Power 1100'),...
                            'C:\Users\holos\Documents\power-calibrations\230920_1100nm_500kHz_25AOM_uni_gate_calibration.mat');

% holo = HoloComputer(HoloController(MSocketServer(42042), 'Holo Controller'));

% rwheel = RunningWheel(Input(DAQInput(dq, 'ai2'), 'Running Wheel'));

% laser_eom = LaserEOM(Output(DAQOutput(dq, 'ao0'), 'Laser Trigger'));
% 
% slm = SLM(Output(DAQOutput(dq, 'ao1'), 'SLM Trigger'),...
%           Input(DAQInput(dq, 'ai1'), 'SLM FLip'));

tman.modules.add(si);
% tman.modules.add(ptb); 
% tman.modules.add(holo);
% tman.modules.add(rwheel);
% tman.modules.add(laser_eom);
tman.modules.add(fpc_900);
tman.modules.add(fpc_1100);
tman.set_save_path(save_path);

% Initialize modules
tman.initialize(); % initialize all added modules
tman.set_mouse(mouse);
tman.set_epoch(epoch);
fprintf('All done.\n')

%% Select code?
ptb.controller.run_stimulus(stimulus); % choose your stimulus here?
% si.controller.prepare(true); % ask for triggering
% si.controller.start();


%% stimulus conditions?

lo_power_1 = [0, 2:2:10]; % 900
lo_power_2 = [0, 2:1:6]; % 1100

pwrs = zeros(n_trials, 2);
for ii = 1:n_trials
    pwrs(ii, :) = [lo_power_1(randi(length(lo_power_1))), lo_power_2(randi(length(lo_power_2)))];
end

%% Generate triggers?
ct = 1;

for p = 1:n_trials
    disp(ct)
    ts = tic;
    tman.set_trial_length(3000);

    % fprintf('1100: %dmW | 900: %dmW\n', pwrs(p, 1), pwrs(p, 2))
    %%%%%%%%%
    % % add something here to determine the shutter stuff...
    if pwrs(p, 1) ~= 0
        fpc_900.set_power(pwrs(p, 1)) % in mW
        fpc_900.set_duration(300) % in ms
        fpc_900.set_ontime(300) % in
        fpc_900.set_frequency(10)
    end
    %

    if pwrs(p, 2) ~= 0
        fpc_1100.set_power(pwrs(p, 2)) % in mW
        fpc_1100.set_duration(300) % in ms
        fpc_1100.set_ontime(300) % in
        fpc_1100.set_frequency(10)
    end

    si.trigger.set([1, 25, 1]); % trigger the start of the trial
    ptb.trigger.set([1, 25, 1]);
    
    tman.prepare();
    
    ts2 = tic;
    tman.start_trial();
    
    tman.end_trial();


    t2 = toc(ts);

    t1 = toc(ts2);
    fprintf('Total: %0.05f\n', t1)
    fprintf('ITI: %0.05f\n', t2);    
    ct = ct + 1;
end


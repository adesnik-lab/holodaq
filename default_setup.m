addpath('K:\')
addpath(genpath('C:\Users\holos\Documents\_code'))
loc = FrankenScopeRigFile();

warning('off', 'MATLAB:structOnObject');


fprintf('Loading defaults... ')
pause(0.1)
fprintf('OK.\n')

fprintf('Making MATLAB NIDAQ object... ')
dq = daq('ni');
dq.Rate = 20000;
pause(0.1)
fprintf('OK.\n')

fprintf('Making serialport object... ')
sp = serialport("COM5", ...
    9600,...
    'ByteOrder', 'big-endian',...
    'Parity', 'none',...
    'StopBits', 1,...
    'DataBits', 8);
sp.configureTerminator('CR/LF');
pause(0.1)
fprintf('OK.\n')

power_calibrations;

tm = TrialManager(dq);
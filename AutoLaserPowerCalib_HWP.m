%% What is tthe rep rate?

addpath(genpath('C:\Users\holos\Documents\GitHub'))
addpath(genpath('C:\Users\holos\Documents\_code'))

clear
clc
close all;
% fill this in
wavelength = 1100;
used_khz = 500;
aom = 0.25;
gate = 'uni'; % or none or normal?

save_base = 'C:\Users\holos\Documents\power-calibrations\';

%% start visa thing (older matlabs)
% note: use instrhwinfo to find the correct dev
addpath(genpath('C:\Users\holos\Documents\GitHub\holodaq'));

instrreset()
vinfo = instrhwinfo('visa','ni');
v = eval(vinfo.ObjectConstructorName{1});
fopen(v);

%% Params
nsamplesPM = 1000; % counts (at 1000 Hz I think), produces an average
interStepPause = 5; % seconds

%% initialize the thing

dq = daq('ni');

s = serialport("COM5", ...
    9600,...
    'ByteOrder', 'big-endian',...
    'Parity', 'none',...
    'StopBits', 1,...
    'DataBits', 8);
s.configureTerminator('CR/LF');

switch wavelength
    case 900
        dq.addoutput('Dev1', 'port0/line5', 'Digital'); % 0/5: 920, 0/6: 1100
        hwp = ELL14(SerialInterface(s), 0, 'hwp'); % 0: 900, 1:1100 % might need both? idk
    case 1100
        dq.addoutput('Dev1', 'port0/line6', 'Digital'); % 0/5: 920, 0/6: 1100
        hwp = ELL14(SerialInterface(s), 1, 'hwp'); % 0: 900, 1:1100 % might need both? idk
end
disp('Devices connected.')

%% 
hwp.moveto(0); % start at 0
dq.write(0); % close shutter

%%
disp('Do this calibration with the z-block in place')
disp('On the Holography Computer put a hologram near the zero order')
disp('Put Laser Gate on Bypass') %added 3/18/21

%% initial search for low and high points
initial_search_queries = linspace(0, 120, 60); % 0 to 70

initial_search_values = zeros(size(initial_search_queries));

% start
dq.write(1);
for ii = 1:numel(initial_search_queries)
    hwp.moveto(initial_search_queries(ii)); % move to deg
    pause(interStepPause);

    fprintf(v, ['sense:average:count ', num2str(nsamplesPM)]);
    set(v, 'timeout', 3+1.1*nsamplesPM*3/1000)
    ret = query(v, 'read?');
    val = str2double(ret)*1000;
    if val < 0
        val = 0;
    end
    initial_search_values(ii) = val;
    disp(['Deg: ' num2str(initial_search_queries(ii)) ' Power (mW):  ' num2str(val)])
end
dq.write(0);

%% find hi-low
[max_pwr, max_idx] = max(initial_search_values(3:end-3)); %exclude ends
[min_pwr, min_idx] = min(initial_search_values(3:end-3));

max_idx = max_idx + 2;
min_idx = min_idx + 2;

segment = linspace(min_idx, max_idx, abs(max_idx-min_idx) + 1);
plot(initial_search_queries(segment), initial_search_values(segment));
fprintf('Initial Search Report\n Max: %0.2fmW at %0.2fdeg \n Min: %0.2fmW and %0.2fdeg\n',...
    max_pwr, initial_search_queries(max_idx), min_pwr, initial_search_queries(min_idx));

% ensure monotonic
if any(diff(sign(diff(initial_search_values(segment)))))
    error('Check it out manually...')
end

% %%
% % fine search
% buffer = 2; % degrees
% fraction_split = 5;
% n_pts_per_section = 30;
% 
% start = initial_search_queries(min_idx);
% stop = initial_search_queries(max_idx); % in case we miss the min/max
% section = (stop - start)/fraction_split; % if negative ok
% 
% start = start - sign(section)*buffer;
% stop = stop + sign(section)*buffer;
% 
% % split into 3 sections
% fine_search = cat(2,...
%     linspace(start, start + section, n_pts_per_section),...
%     linspace(start + section + section/n_pts_per_section, stop - section, n_pts_per_section),...
%     linspace(stop - section + section/n_pts_per_section, stop, n_pts_per_section));
% 
% %% start fine search
% % start
% dq.write(1); % open shutter
% fine_search_values = zeros(size(fine_search));
% for ii = 1:numel(fine_search)
%     hwp.moveto(fine_search(ii)); % move to deg
%     pause(interStepPause);
% 
%     fprintf(v, ['sense:average:count ', num2str(nsamplesPM)]);
%     set(v, 'timeout', 3+1.1*nsamplesPM*3/1000)
%     ret = query(v, 'read?');
%     val = str2double(ret)*1000;
%     if val < 0
%         val = 0;
%     end
%     fine_search_values(ii) = val;
%     disp(['Deg: ' num2str(fine_search(ii)) ' Power (mW):  ' num2str(val)])
% end
% dq.write(0); % close shutter

% %% post-processing 
% % scaling
% scale = 500/used_khz;
% % find minmax again
% [max_pwr, max_idx_final] = max(initial_search_values); %exclude ends
% [min_pwr, min_idx_final] = min(initial_search_values);
% use_pts = min_idx_final:max_idx_final;
% 
% [f, gof] = fit(scale * fine_search_values(use_pts)', fine_search(use_pts)', 'poly3', 'Robust', 'Bisquare');
% fprintf('Fit R2: %0.04f\n', gof.rsquare)
% 
% figure;
% plot(f, scale* fine_search_values(use_pts), fine_search(use_pts))
% legend('Location', 'southeast')
% ylabel('HWP angle (deg)')
% xlabel('Power (mW)')
% shg


%% interp only
%% information
calib = struct();
% calib.max_power = max_pwr * scale;
% calib.min_power = min_pwr * scale;
% 
calib.max_deg = initial_search_queries(max_idx);
calib.min_deg = initial_search_queries(min_idx);
calib.max_power = initial_search_values(max_idx);
calib.min_power = initial_search_values(min_idx);

calib.degrees = initial_search_queries(segment);
calib.powers = initial_search_values(segment);
% 
% fprintf('Maximum power: %0.02f mW at %0.02fdeg\n', calib.max_power, calib.max_deg)
% fprintf('Minumum power: %0.02f mW at %0.02fdeg\n', calib.min_power, calib.min_deg)

%% save
fn = fullfile(save_base, sprintf('%s_%dnm_%dkHz_%dAOM_%s_gate_calibration.mat', datetime('now', 'Format', 'yyMMdd'), wavelength, used_khz, aom*100, gate));
save(fn, 'calib')

fprintf('Saved in %s\n', fn)
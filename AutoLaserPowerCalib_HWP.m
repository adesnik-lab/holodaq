%% start visa thing (older matlabs)
% note: use instrhwinfo to find the correct dev

vinfo = instrhwinfo('visa','ni');
vinfo.ObjectConstructorName;
v = visa('ni', 'USB0::0x1313::0x8078::P0031082::INSTR');
fopen(v);

disp('device ready.')

%% Params
nsamplesPM = 1000; % counts (at 1000 Hz I think), produces an average
interStepPause = 5; % seconds

%% initialize the thing

dq = fakedaq;%daq('ni');

s = serialport("/dev/tty.usbserial-DK0DL807", ...
    9600,...
    'ByteOrder', 'big-endian',...
    'Parity', 'none',...
    'StopBits', 1,...
    'DataBits', 8);
s.configureTerminator('CR/LF');

dq.addoutput('Dev1', 'port0/line5', 'Digital');
hwp = ELL14(SerialInterface(s), 0, 'hwp');

%% 
hwp.moveto(0); % start at 0
dq.write(0); % close shutter

%%
disp('Do this calibration with the z-block in place')
disp('On the Holography Computer put a hologram near the zero order')
disp('Put Laser Gate on Bypass') %added 3/18/21

%% initial search for low and high points
initial_search_queries = linspace(0, 90, 40); % 0 to 70

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
[max_pwr, max_idx] = max(initial_search_values);
[min_pwr, min_idx] = min(initial_search_values);

plot(initial_search_queries, initial_search_values);
fprintf('Initial Search Report\n Max: %0.2fmW at %0.2fdeg \n Min: %0.2fmW and %0.f2deg\n',...
    max_pwr, initial_search_queries(max_idx), min_pwr, initial_search_queries(min_idx));

%%
% fine search
buffer = 2; % degrees
start = initial_search_queries(min_idx) - buffer;
stop = initial_search_queries(min_idx) + buffer; % in case we miss the min/max

thirds = (stop - start)/3; % if negative ok
n_pts_per_section = 10;

% split into 3 sections
fine_search = cat(1,...
    linspace(start, start + thirds, n_pts_per_section),...
    linspace(start + thirds, start + 2 * thirds, n_pts_per_section),...
    linspace(start + 2 * thirds, stop), n_pts_per_section);

%% start fine search
% start
dq.write(1); % open shutter
fine_search_values = zeros(size(fine_search));
for ii = 1:numel(fine_search)
    hwp.moveto(fine_search(ii)); % move to deg
    pause(interStepPause);

    fprintf(v, ['sense:average:count ', num2str(nsamplesPM)]);
    set(v, 'timeout', 3+1.1*nsamplesPM*3/1000)
    ret = query(v, 'read?');
    val = str2double(ret)*1000;
    if val < 0
        val = 0;
    end
    fine_search_values(ii) = val;
    disp(['Deg: ' num2str(initial_search_queries(ii)) ' Power (mW):  ' num2str(val)])
end
dq.write(0); % close shutter


%% fit
ft = fittype('sin((x - shift)/xscale)*yscale','coefficients',{'shift','xscale','yscale'});
pwr_curve = fit(X, Y, ft);

plot(fine_search, fine_search_values);
hold on
plot(pwr_curve, fine_search, fine_search_values);

%%

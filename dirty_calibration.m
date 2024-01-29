dq = daq('ni');
dq.addoutput('dev1', 'ao0', 'Voltage');


addpath(genpath('C:\Users\holos\Documents\GitHub\holodaq'));

vinfo = instrhwinfo('visa','ni');
v = eval(vinfo.ObjectConstructorName{1});
fopen(v);

disp('device ready.')

%% Params
nsamplesPM = 1000; % counts (at 1000 Hz I think), produces an average
interStepPause = 5; % seconds


%% initial search for low and high points
initial_search_queries = linspace(0, 0.6, 50); % 0 to 70

initial_search_values = zeros(size(initial_search_queries));

% start
for ii = 1:numel(initial_search_queries)
    dq.write(initial_search_queries(ii))
   
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

%%

% linear interp

V = initial_search_queries(35:end);
P = scaled_values(35:end);

what_voltage = @(P_request) interp1(P, V, P_request);

%% usage
pwr = 25;
dq.write(what_voltage(pwr));
disp('power set')
pause(.1)
dq.write(0)
%%
clc
dq.write(0)
disp('power set to 0')

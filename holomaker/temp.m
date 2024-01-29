
holoRequest = importdata('holoRequest.mat');

% choose targets to assemble into holograms
h = Holomaker();

holo_rois = {[1], [1, 2]}; %equv to rois, it means use the first roi as a hologram...


holoRequest.rois = holo_rois;

% send to the holography computer and get DEs back?

% receive back holoRequest... has 
% choose a sequenc

firing_order = [1, 2, 1]; % first, second, first hologram...

hz = [5, 5, 5];

power = [1, 1, 1];

duration = [2, 2, 2];

on_time = [10, 10, 10]/1000;

% pass thees into a thing which creates everything...

trig_maker(info)


%% TRIAL START
%send to the holography computer
%mssend(firing_order);

% then it works?/Users/kevinsit/Work/code/holodaq/interfaces/daq/DAQOutput.m
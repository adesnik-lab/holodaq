function sig = opto_signature(chans)
%OPTO_SIGNATURE Deterministic string identifying an ordered opto channel table.
%   sig = OPTO_SIGNATURE(chans) summarises the table opto_channels returned, in
%   order, as e.g.
%
%       'blue@900#auto|red@1100#auto'
%
%   Purpose: the DAQ and the holography computer must agree on which channel is
%   which, and in what order holoRequests arrive. Today they agree only by
%   convention -- start_holo_listener takes its wavelength list as a launch
%   parameter and never checks it against what the DAQ actually sends, so a
%   listener started with the order reversed compiles every hologram against the
%   wrong wavelength's SLM calibration, silently.
%
%   Both sides compute this from their own view and compare. A mismatch is a
%   refusal, not a warning: the failure it prevents is a beam steered by the
%   wrong phase mask.
%
%   Sensitive to name, wavelength, board and ORDER -- everything that decides
%   which physical device a trial's stimulus reaches. Deliberately NOT sensitive
%   to module names or LUT paths, which are per-machine and legitimately differ
%   between the DAQ's rig file and the holo computer's inventory.
%
%   See also: opto_channels, opto_channel

    if isempty(chans)
        sig = 'none';
        return
    end

    parts = cell(1, numel(chans));
    for i = 1:numel(chans)
        c = chans(i);
        if isempty(c.slm_board)
            board = 'auto';
        else
            board = sprintf('%d', c.slm_board);
        end
        parts{i} = sprintf('%s@%d#%s', c.name, c.wavelength, board);
    end
    sig = strjoin(parts, '|');
end

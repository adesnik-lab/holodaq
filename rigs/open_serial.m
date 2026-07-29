function sp = open_serial(cfg)
%OPEN_SERIAL Open a serialport from a rig.serial.<name> config struct.
%   sp = OPEN_SERIAL(rig.serial.ell14)
%
%   Recognized fields (only 'port' is required):
%     port        'COM4'
%     baud        9600           (default)
%     byte_order  'big-endian'   -> serialport ByteOrder
%     parity      'none'         -> Parity
%     stop_bits   1              -> StopBits
%     data_bits   8              -> DataBits
%     terminator  'CR/LF'        (default; applied via configureTerminator)
%
%   See also LOAD_RIG, SERIALPORT.

    assert(isstruct(cfg) && isfield(cfg, 'port') && ~isempty(cfg.port), ...
        'open_serial:port', 'Serial config needs a ''port'' field (e.g. ''COM4'').');

    baud = 9600;
    if isfield(cfg, 'baud')
        baud = cfg.baud;
    end

    nv = {};
    map = {'byte_order', 'ByteOrder'; ...
           'parity',     'Parity'; ...
           'stop_bits',  'StopBits'; ...
           'data_bits',  'DataBits'};
    for i = 1:size(map, 1)
        if isfield(cfg, map{i, 1})
            nv = [nv, map(i, 2), {cfg.(map{i, 1})}]; %#ok<AGROW>
        end
    end

    sp = serialport(cfg.port, baud, nv{:});

    terminator = 'CR/LF';
    if isfield(cfg, 'terminator')
        terminator = cfg.terminator;
    end
    sp.configureTerminator(terminator);
end

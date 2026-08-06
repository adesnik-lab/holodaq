function [si_root, mode, gui] = parse_si_listener_args(varargin)
%PARSE_SI_LISTENER_ARGS Split start_si_listener's arguments into root + mode + gui.
%   [si_root, mode, gui] = PARSE_SI_LISTENER_ARGS(...)
%
%   The tiff root stays POSITIONAL so start_si_listener('E:') keeps meaning what it
%   always did, and 'blocking' / 'async' / 'gui' / 'nogui' are recognised as keywords
%   in any position. Matching is case-insensitive and tolerates surrounding
%   whitespace.
%
%       ()                  -> si_root = '',   mode = 'async',    gui = true
%       ('E:')              -> si_root = 'E:', mode = 'async',    gui = true
%       ('blocking')        -> si_root = '',   mode = 'blocking', gui = true
%       ('E:', 'blocking')  -> si_root = 'E:', mode = 'blocking', gui = true
%       ('nogui')           -> si_root = '',   mode = 'async',    gui = false
%
%   gui only asks for the status window; whether one is possible is
%   start_si_listener's call (blocking mode has no usable window).
%
%   Split out of start_si_listener so it can be tested: that function calls
%   addpath(genpath(...)) on the whole repo, which prepends the real receivers to the
%   path, so a stub SIReceiver cannot shadow the real one and the argument handling
%   was untestable in place.
%
%   See also: start_si_listener, test_si_listener_args

    mode = 'async';
    gui  = true;
    args = varargin;
    keep = true(1, numel(args));
    for i = 1:numel(args)
        if ischar(args{i}) || isstring(args{i})
            switch lower(strtrim(char(args{i})))
                case 'blocking', mode = 'blocking'; keep(i) = false;
                case 'async',    mode = 'async';    keep(i) = false;
                case 'gui',      gui  = true;       keep(i) = false;
                case 'nogui',    gui  = false;      keep(i) = false;
            end
        end
    end
    args = args(keep);

    assert(numel(args) <= 1, 'start_si_listener:tooManyArgs', ...
        ['Expected at most a tiff root plus ''blocking''/''async''/''nogui''; got %d ' ...
         'other argument(s). Usage: start_si_listener(''E:'', ''blocking'')'], numel(args));

    si_root = '';
    if ~isempty(args), si_root = char(string(args{1})); end
end

function test_si_listener_args()
%TEST_SI_LISTENER_ARGS  start_si_listener's argument forms. Offline, no rig.
%
%   >> addpath(genpath(<holodaq>)); test_si_listener_args
%
%   The point of these cases is that async became the DEFAULT, so every previously
%   valid invocation has to keep meaning what it meant -- in particular
%   start_si_listener('E:') must still set the tiff root and not be mistaken for a
%   mode keyword.

    cases = { ...
        {},                 '',   'async'    ; ...   % bare: async is now the default
        {'E:'},             'E:', 'async'    ; ...   % the pre-existing usage
        {'blocking'},       '',   'blocking' ; ...   % opt back out
        {'E:', 'blocking'}, 'E:', 'blocking' ; ...
        {'blocking', 'E:'}, 'E:', 'blocking' ; ...   % order-insensitive
        {'BLOCKING'},       '',   'blocking' ; ...   % case-insensitive
        {'  blocking  '},   '',   'blocking' ; ...   % whitespace-tolerant
        {'async'},          '',   'async'    ; ...   % explicit async is allowed
        {'E:', 'async'},    'E:', 'async'    ; ...
        {"E:"},             'E:', 'async'    };      % string, not char

    for i = 1:size(cases, 1)
        [root, mode] = parse_si_listener_args(cases{i, 1}{:});
        assert(strcmp(root, cases{i, 2}), 'case %d: root "%s", want "%s"', ...
            i, root, cases{i, 2});
        assert(strcmp(mode, cases{i, 3}), 'case %d: mode "%s", want "%s"', ...
            i, mode, cases{i, 3});
        assert(ischar(root), 'case %d: root must be char, got %s', i, class(root));
    end

    % last keyword wins, so a scripted override can append one
    [~, mode] = parse_si_listener_args('blocking', 'async');
    assert(strcmp(mode, 'async'), 'the last mode keyword should win, got %s', mode);

    % two roots is a mistake, not a silent truncation
    try
        parse_si_listener_args('E:', 'F:');
        error('test:noThrow', 'two tiff roots must be rejected');
    catch e
        assert(strcmp(e.identifier, 'start_si_listener:tooManyArgs'), ...
            'wrong error id: %s', e.identifier);
    end

    fprintf('PASS test_si_listener_args (%d forms; async default, ''E:'' still a root).\n', ...
        size(cases, 1));
end

%PRINT2EPS  Prints figures to eps with improved line styles
%
% Examples:
%   print2eps filename
%   print2eps(filename, fig_handle)
%   print2eps(filename, fig_handle, bb_padding)
%   print2eps(filename, fig_handle, bb_padding, options)
%
% This function saves a figure as an eps file, with two improvements over
% MATLAB's print command. First, it improves the line style, making dashed
% lines more like those on screen and giving grid lines their own dotted
% style. Secondly, it substitutes original font names back into the eps
% file, where these have been changed by MATLAB, for up to 11 different
% fonts.
%
%IN:
%   filename - string containing the name (optionally including full or
%              relative path) of the file the figure is to be saved as. A
%              ".eps" extension is added if not there already. If a path is
%              not specified, the figure is saved in the current directory.
%   fig_handle - The handle of the figure to be saved. Default: gcf().
%   bb_padding - Scalar value of amount of padding to add to border around
%                the figure, in points. Can be negative as well as
%                positive. Default: 0.
%   options - Additional parameter strings to be passed to print.

% Copyright (C) Oliver Woodford 2008-2014

% The idea of editing the EPS file to change line styles comes from Jiro
% Doke's FIXPSLINESTYLE (fex id: 17928)
% The idea of changing dash length with line width came from comments on
% fex id: 5743, but the implementation is mine :)

% 14/11/2011: Fix a MATLAB bug rendering black or white text incorrectly.
%             Thanks to Mathieu Morlighem for reporting the issue and
%             obtaining a fix from TMW.
% 08/12/11: Added ability to correct fonts. Several people have requested
%           this at one time or another, and also pointed me to printeps
%           (fex id: 7501), so thank you to them. My implementation (which
%           was not inspired by printeps - I'd already had the idea for my
%           approach) goes slightly further in that it allows multiple
%           fonts to be swapped.
% 14/12/11: Fix bug affecting font names containing spaces. Thanks to David
%           Szwer for reporting the issue.
% 25/01/12: Add a font not to be swapped. Thanks to Anna Rafferty and Adam
%           Jackson for reporting the issue. Also fix a bug whereby using a
%           font alias can lead to another font being swapped in.
% 10/04/12: Make the font swapping case insensitive.
% 26/10/12: Set PaperOrientation to portrait. Thanks to Michael Watts for
%           reporting the issue.
% 26/10/12: Fix issue to do with swapping fonts changing other fonts and
%           sizes we don't want, due to listeners. Thanks to Malcolm Hudson
%           for reporting the issue.
% 22/03/13: Extend font swapping to axes labels. Thanks to Rasmus Ischebeck
%           for reporting the issue.
% 23/07/13: Bug fix to font swapping. Thanks to George for reporting the
%           issue.
% 13/08/13: Fix MATLAB feature of not exporting white lines correctly.
%           Thanks to Sebastian He?linger for reporting it.

function print2eps(name, fig, bb_padding, varargin)
options = {'-depsc2'};
if nargin > 3
    options = [options varargin];
elseif nargin < 3
    bb_padding = 0;
    if nargin < 2
        fig = gcf();
    end
end
% Construct the filename
if numel(name) < 5 || ~strcmpi(name(end-3:end), '.eps')
    name = [name '.eps']; % Add the missing extension
end
% Set paper size
old_pos_mode = get(fig, 'PaperPositionMode');
old_orientation = get(fig, 'PaperOrientation');
set(fig, 'PaperPositionMode', 'auto', 'PaperOrientation', 'portrait');
% Find all the used fonts in the figure
font_handles = findall(fig, '-property', 'FontName');
fonts = get(font_handles, 'FontName');
if ~iscell(fonts)
    fonts = {fonts};
end
% Map supported font aliases onto the correct name
fontsl = lower(fonts);
for a = 1:numel(fonts)
    f = fontsl{a};
    f(f==' ') = [];
    switch f
        case {'times', 'timesnewroman', 'times-roman'}
            fontsl{a} = 'times-roman';
        case {'arial', 'helvetica'}
            fontsl{a} = 'helvetica';
        case {'newcenturyschoolbook', 'newcenturyschlbk'}
            fontsl{a} = 'newcenturyschlbk';
        otherwise
    end
end
fontslu = unique(fontsl);
% Determine the font swap table
matlab_fonts = {'Helvetica', 'Times-Roman', 'Palatino', 'Bookman', 'Helvetica-Narrow', 'Symbol', ...
                'AvantGarde', 'NewCenturySchlbk', 'Courier', 'ZapfChancery', 'ZapfDingbats'};
matlab_fontsl = lower(matlab_fonts);
require_swap = find(~ismember(fontslu, matlab_fontsl));
unused_fonts = find(~ismember(matlab_fontsl, fontslu));
font_swap = cell(3, min(numel(require_swap), numel(unused_fonts)));
fonts_new = fonts;
for a = 1:size(font_swap, 2)
    font_swap{1,a} = find(strcmp(fontslu{require_swap(a)}, fontsl));
    font_swap{2,a} = matlab_fonts{unused_fonts(a)};
    font_swap{3,a} = fonts{font_swap{1,a}(1)};
    fonts_new(font_swap{1,a}) = {font_swap{2,a}};
end
% Swap the fonts
if ~isempty(font_swap)
    fonts_size = get(font_handles, 'FontSize');
    if iscell(fonts_size)
        fonts_size = cell2mat(fonts_size);
    end
    M = false(size(font_handles));
    % Loop because some changes may not stick first time, due to listeners
    c = 0;
    update = zeros(1000, 1);
    for b = 1:10 % Limit number of loops to avoid infinite loop case
        for a = 1:numel(M)
            M(a) = ~isequal(get(font_handles(a), 'FontName'), fonts_new{a}) || ~isequal(get(font_handles(a), 'FontSize'), fonts_size(a));
            if M(a)
                set(font_handles(a), 'FontName', fonts_new{a}, 'FontSize', fonts_size(a));
                c = c + 1;
                update(c) = a;
            end
        end
        if ~any(M)
            break;
        end
    end
    % Compute the order to revert fonts later, without the need of a loop
    [update, M] = unique(update(1:c));
    [M, M] = sort(M);
    update = reshape(update(M), 1, []);
end
% MATLAB bug fix - black and white text can come out inverted sometimes
% Find the white and black text
white_text_handles = findobj(fig, 'Type', 'text');
M = get(white_text_handles, 'Color');
if iscell(M)
    M = cell2mat(M);
end
M = sum(M, 2);
black_text_handles = white_text_handles(M == 0);
white_text_handles = white_text_handles(M == 3);
% Set the font colors slightly off their correct values
set(black_text_handles, 'Color', [0 0 0] + eps);
set(white_text_handles, 'Color', [1 1 1] - eps);
% MATLAB bug fix - white lines can come out funny sometimes
% Find the white lines
white_line_handles = findobj(fig, 'Type', 'line');
M = get(white_line_handles, 'Color');
if iscell(M)
    M = cell2mat(M);
end
white_line_handles = white_line_handles(sum(M, 2) == 3);
% Set the line color slightly off white
set(white_line_handles, 'Color', [1 1 1] - 0.00001);
% Print to eps file
print(fig, options{:}, name);
% Reset the font and line colors
set(black_text_handles, 'Color', [0 0 0]);
set(white_text_handles, 'Color', [1 1 1]);
set(white_line_handles, 'Color', [1 1 1]);
% Reset paper size
set(fig, 'PaperPositionMode', old_pos_mode, 'PaperOrientation', old_orientation);
% Reset the font names in the figure
if ~isempty(font_swap)
    for a = update
        set(font_handles(a), 'FontName', fonts{a}, 'FontSize', fonts_size(a));
    end
end
% Do post-processing on the eps file
try
    fstrm = read_write_entire_textfile(name);
catch
    warning('Loading EPS file failed, so unable to perform post-processing. This is usually because the figure contains a large number of patch objects. Consider exporting to a bitmap format in this case.');
    return
end
% Replace the font names
if ~isempty(font_swap)
    for a = 1:size(font_swap, 2)
        %fstrm = regexprep(fstrm, [font_swap{1,a} '-?[a-zA-Z]*\>'], font_swap{3,a}(~isspace(font_swap{3,a})));
        fstrm = regexprep(fstrm, font_swap{2,a}, font_swap{3,a}(~isspace(font_swap{3,a})));
    end
end
if using_hg2(fig)
    % Convert miter joins to line joins
    fstrm = regexprep(fstrm, '10.0 ML\n', '1 LJ\n');
    % Move the bounding box to the top of the file
    [s, e] = regexp(fstrm, '%%BoundingBox: [\w\s()]*%%');
    if numel(s) == 2
        fstrm = fstrm([1:s(1)-1 s(2):e(2)-2 e(1)-1:s(2)-1 e(2)-1:end]);
    end
else
    % Fix the line styles
    fstrm = fix_lines(fstrm);
end
% Apply the bounding box padding
if bb_padding
    add_padding = @(n1, n2, n3, n4) sprintf(' %d', str2double({n1, n2, n3, n4}) + [-bb_padding -bb_padding bb_padding bb_padding]);
    fstrm = regexprep(fstrm, '%%BoundingBox:[ ]+([-]?\d+)[ ]+([-]?\d+)[ ]+([-]?\d+)[ ]+([-]?\d+)', '%%BoundingBox:${add_padding($1, $2, $3, $4)}');
end
% Write out the fixed eps file
read_write_entire_textfile(name, fstrm);
end

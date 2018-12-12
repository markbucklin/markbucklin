function p = cellToPipe(c)
%CELLTOPIPE Convert a cell array of substrings to a single string where
%each of the substrings are separated by the pipe delimiter '|'
%   p = Simulink.scopes.cellToPipe(c)
%       c: A cell array of the substrings
%       p: A string with substrings separated by the pipe delimiter '|'
%   Example:
%       c = {'none','d','p','o','square'}
%       p = uiservices.cellToPipe(c)

%   Copyright 2010 The MathWorks, Inc.

p = '';
if ~isempty(c)
    for k = 1:numel(c) % use linear indexing
        p = [p c{k} '|']; %#ok<AGROW>
    end
    p = p(1:end-1);
end

% [EOF]

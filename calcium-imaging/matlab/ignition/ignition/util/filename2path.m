function pth = filename2path(files)
% This function turns a full path into a path prefix suitable for
% the MATLAB path. Since @, +, and private directories cannot appear
% directly on the MATLAB path, this function removes them from the
% returned path prefix.
%
% Copyright 2015, The MathWorks, Inc.

if ischar(files)
    files = { files };
end

num_files = numel(files);
pth = cell(size(files));

%try to find the first '/+' or '/@' or '/private'
if ismac
    % Temp directories start with '/private/' on Mac.
    pat = '(?!^[/\\]private[/\\].+)[/\\]([@+]|private[/\\]).*';
else
    pat = '[/\\]([@+]|private[/\\]).*';
end

for i = 1:num_files
    At_Plus_Private_Idx = regexp(files{i}, pat, 'ONCE');
    
    if ~isempty(At_Plus_Private_Idx)
        pth{i} = files{i}(1:At_Plus_Private_Idx-1);
    else
        if matlab.depfun.internal.cacheExist(files{i},'dir')
            pth{i} = files{i};
        else
            [pth{i},~,~] = fileparts(files{i});
        end
    end
end
end

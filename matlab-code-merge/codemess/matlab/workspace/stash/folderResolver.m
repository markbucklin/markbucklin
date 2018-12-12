function fullName = folderResolver(folder)
% This function is undocumented.

%  Copyright 2015 The MathWorks, Inc.

validateattributes(folder,{'char'},{'row'},'', 'folder');

if ~exist(folder, 'dir')
    error(message('MATLAB:unittest:FileIO:InvalidFolder', folder));
end

[status, folderInfo] = fileattrib(folder);
if ~(status && folderInfo.directory)
    error(message('MATLAB:unittest:FileIO:InvalidFolder', folder));
end

fullName = folderInfo.Name;
end


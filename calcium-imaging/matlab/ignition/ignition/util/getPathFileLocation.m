function pathFileLocation = getPathFileLocation(pathFileName)
% getPathFileLocation Returns the location of the file that stores a list
% of add-on folders that should be added to the MATLAB search path or the
% dynamic Java class path

% Copyright 2016 The MathWorks, Inc.

s = settings;
temp = s.matlab.addons.InstallationFolder.ActiveValue;
if isempty(temp)
    userPathString = userpath;
    userPathFolders = strsplit(userPathString, {pathsep,';'});
    firstFolder = userPathFolders{1};
    if (isdir(firstFolder))
        userWorkFolder = firstFolder;
    else
        userWorkFolder = system_dependent('getuserworkfolder', 'default');
    end
    pathFileLocation = fullfile(userWorkFolder, 'Add-Ons', pathFileName);
else
    pathFileLocation = ...
        fullfile(temp, pathFileName);
end

end
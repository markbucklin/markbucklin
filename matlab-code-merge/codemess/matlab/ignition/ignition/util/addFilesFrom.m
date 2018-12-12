function addFilesFrom(fileLocation, addfcn, foldersOnly)
% addFilesFrom Opens the specified file, reads in the list of
% folders, and adds them to the MATLAB search path.

% Copyright 2014-2016 The MathWorks, Inc.

fileId = fopen(fileLocation, 'r', 'n', 'UTF-8');
cannotOpenFile = (fileId == -1); % FOPEN returns -1 if it cannot open the file.
if cannotOpenFile
    if iIsFile(fileLocation)
        warning(message('MATLAB:addons_search_path:warning:FileNotReadable', fileLocation));
    end
    % The path file cannot be opened. This will happen to every user who
    % has not yet installed a custom Toolbox, because the path file does
    % not exist. Do nothing in this case.
    return;
end
fileCloser = onCleanup(@()fclose(fileId));

toolboxesFolder = fileparts(fileLocation);
folders = iGetFoldersFrom(fileId, toolboxesFolder, foldersOnly);
if isempty(folders)
    return;
end

% javaaddpath doesn't support calling with the entire list of files and the
% '-end' flag in one call, so iterate over the list and pass them in one by
% one
for k=1:length(folders)
    addfcn(folders{k}, '-end');
end

end

function folders = iGetFoldersFrom(fileId, toolboxesFolder, foldersOnly)
folders = {};
foldersBuffer = {};

currentLine = fgetl(fileId);
while ischar(currentLine)
    if isempty(currentLine)
        potentialError = ferror(fileId);
        if ~isempty(potentialError)
            warning(message('MATLAB:addons_search_path:warning:ErrorReadingFile', potentialError));
            return;
        end
        currentLine = fgetl(fileId);
        continue;
    end
    
    absolutePathToFolder = fullfile(toolboxesFolder, currentLine);
    if foldersOnly && ~iIsFolder(absolutePathToFolder)
        warning(message('MATLAB:addons_search_path:warning:InvalidFolder', absolutePathToFolder));
        currentLine = fgetl(fileId);
        continue;
    end
    
    foldersBuffer = [foldersBuffer absolutePathToFolder]; %#ok<AGROW> Suppress the 'preallocating' mlint warning. We can't preallocate the 'folders' cell array because we don't know its final length.
    currentLine = fgetl(fileId);
end

folders = foldersBuffer;

end

function result = iIsFile(location)
result = exist(location, 'file') == 2; % EXIST returns 2 if 'location' is the full pathname to a file.
end

function result = iIsFolder(location)
result = exist(location, 'dir') == 7; % EXIST returns 7 if 'location' is a directory.
end
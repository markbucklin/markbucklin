function addFoldersToPathFrom(fileLocation)
% addFoldersToPathFrom Opens the specified file, reads in the list of
% folders, and adds them to the MATLAB search path.

% Copyright 2014-2016 The MathWorks, Inc.

addFilesFrom(fileLocation, @addpath, true);
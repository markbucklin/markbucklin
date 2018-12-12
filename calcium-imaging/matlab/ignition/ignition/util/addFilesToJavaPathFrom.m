function addFilesToJavaPathFrom(fileLocation)
% addFilesToJavaPathFrom Opens the specified file, reads in the list of
% folders, and adds them to the Java dynamic class path.

% Copyright 2016 The MathWorks, Inc.

addFilesFrom(fileLocation, @javaaddpath, false);
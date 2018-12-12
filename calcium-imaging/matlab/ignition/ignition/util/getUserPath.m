function userPath = getUserPath
% getUserPath returns 'userpath' as set by user, or
% system dependent default otherwise

% Copyright 2015 The MathWorks Inc.
userPathString = userpath;
userPathFolders = strsplit(userPathString, {pathsep,';'});
firstFolder = userPathFolders{1};
if (isdir(firstFolder))
    userPath = firstFolder;
else
    userPath = system_dependent('getuserworkfolder','default');
end
end


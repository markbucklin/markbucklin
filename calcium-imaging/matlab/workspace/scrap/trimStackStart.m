function stack = trimStackStart(stack)
% This function is undocumented.

%  Copyright 2013-2015 MathWorks, Inc.

% Trim the start

import matlab.unittest.internal.isQualifyingPluginInFrameworkFolder;

files = {stack.file};
frameworkFolder = matlab.unittest.internal.getFrameworkFolder;
testContentFrames = ~strncmp(files, frameworkFolder, numel(frameworkFolder)) | ...
    isQualifyingPluginInFrameworkFolder(files);
firstTestContentFrame = find(testContentFrames,1);
if isempty(firstTestContentFrame)
    stack(:) = [];
else
    stack(1:firstTestContentFrame-1) = [];
end

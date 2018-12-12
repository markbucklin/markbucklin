function stack = trimStackEnd(stack)
% This function is undocumented.

%  Copyright 2013-2015 MathWorks, Inc.

import matlab.unittest.internal.isQualifyingPluginInFrameworkFolder;

% Trim the end of the stack. This means trimming all stack frames that are
% below the first call to TestRunner.evaluateMethodCore and any framework
% stack frames immediately above that. The evaluateMethodCore contract is
% that it will tightly wrap all test content. Then we simply need to remove
% internal wrappers such as runTeardown and FunctionTestCase after the
% first evaluateMethodCore call. Also, confirm that is it the framework's
% TestRunner.evaluateMethodCore and not another class named TestRunner with
% a method named evaluateMethodCore.
names = {stack.name};
evaluateMethodIndices = find(strcmp(names, 'TestRunner.evaluateMethodCore'));

frameworkFolder = matlab.unittest.internal.getFrameworkFolder;

% Match a TestRunner file with any extension
testRunnerLocation = fullfile(frameworkFolder,'core','+matlab','+unittest','TestRunner.');
runnerLocationLength = numel(testRunnerLocation);

for idx = fliplr(evaluateMethodIndices)
    if strncmp(stack(idx).file, testRunnerLocation, runnerLocationLength)
        stack(idx:end) = [];
        break;
    end
end

files = {stack.file};
testContentFrames = ~strncmp(files, frameworkFolder, numel(frameworkFolder)) | ...
    isQualifyingPluginInFrameworkFolder(files);
lastTestContentFrame = find(testContentFrames,1,'last');
if isempty(lastTestContentFrame)
    stack(:) = [];
else
    stack(lastTestContentFrame+1:end) = [];
end

% Trim the stack for qualifications that occur inside of plugins. The
% contract is that TestRunnerPlugin.invokeTestContentOperatorMethod_
% tightly wraps all plugin method calls.
names = {stack.name};
files = {stack.file};
idx = find(strcmp(names, 'TestRunnerPlugin.invokeTestContentOperatorMethod_') & ...
    strncmp(files, frameworkFolder, numel(frameworkFolder)), 1, 'first');
if ~isempty(idx)
    stack = stack(1:idx-1);
end


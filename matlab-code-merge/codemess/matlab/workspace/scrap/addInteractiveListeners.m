function addInteractiveListeners(testCase)
% This function is undocumented.

% Copyright 2015 The MathWorks, Inc.

% Add passing listeners
testCase.addlistener('VerificationPassed'  , @(varargin)handlePassingInteractiveVerification(varargin{:}));
testCase.addlistener('AssertionPassed'     , @(varargin)handlePassingInteractiveAssertion(varargin{:}));
testCase.addlistener('FatalAssertionPassed', @(varargin)handlePassingInteractiveFatalAssertion(varargin{:}));
testCase.addlistener('AssumptionPassed'    , @(varargin)handlePassingInteractiveAssumption(varargin{:}));

% Add failing listeners
testCase.addlistener('VerificationFailed'  , @(varargin)handleFailingInteractiveVerification(varargin{:}));
testCase.addlistener('AssertionFailed'     , @(varargin)handleFailingInteractiveAssertion(varargin{:}));
testCase.addlistener('FatalAssertionFailed', @(varargin)handleFailingInteractiveFatalAssertion(varargin{:}));
testCase.addlistener('AssumptionFailed'    , @(varargin)handleFailingInteractiveAssumption(varargin{:}));

% Add diagnostic logging listener
testCase.addlistener('DiagnosticLogged'    , @(varargin)handleDiagnosticLogged(varargin{:}));
end

function handlePassingInteractiveVerification(varargin)
printLine(getString(message('MATLAB:unittest:Interactive:VerificationPassed')));
end
function handlePassingInteractiveAssertion(varargin)
printLine(getString(message('MATLAB:unittest:Interactive:AssertionPassed')));
end
function handlePassingInteractiveFatalAssertion(varargin)
printLine(getString(message('MATLAB:unittest:Interactive:FatalAssertionPassed')));
end
function handlePassingInteractiveAssumption(varargin)
printLine(getString(message('MATLAB:unittest:Interactive:AssumptionPassed')));
end

function handleFailingInteractiveVerification(~, evd)
printLine(getString(message('MATLAB:unittest:Interactive:VerificationFailed')));
printDiagnosticsFromEventData(evd);
end
function handleFailingInteractiveAssertion(~, evd)
printLine(getString(message('MATLAB:unittest:Interactive:AssertionFailed')));
printDiagnosticsFromEventData(evd);
end
function handleFailingInteractiveFatalAssertion(~, evd)
printLine(getString(message('MATLAB:unittest:Interactive:FatalAssertionFailed')));
printDiagnosticsFromEventData(evd);
end
function handleFailingInteractiveAssumption(~, evd)
printLine(getString(message('MATLAB:unittest:Interactive:AssumptionFailed')));
printDiagnosticsFromEventData(evd);
end

function handleDiagnosticLogged(~, evd)
printLine(getString(message('MATLAB:unittest:Interactive:DiagnosticLogged')));
diagResults = evd.DiagnosticResult;
for ct = 1:numel(diagResults)
    thisResult = diagResults{ct};
    if ~isempty(thisResult)
        printLine(thisResult);
    end
end
end

function printDiagnosticsFromEventData(evd)
printHeaderAndDiagnosticResults(...
    getString(message('MATLAB:unittest:Diagnostic:TestDiagnosticHeader')), ...
    evd.TestDiagnosticResult);

printHeaderAndDiagnosticResults(...
    getString(message('MATLAB:unittest:Diagnostic:FrameworkDiagnosticHeader')), ...
    evd.FrameworkDiagnosticResult);
end

function printLine(string)
fprintf(1, '%s\n', string);
end

function printHeaderAndDiagnosticResults(header, diagResults)
import matlab.unittest.internal.diagnostics.wrapHeader;
for ct = 1:numel(diagResults)
    thisResult = diagResults{ct};
    if ~isempty(thisResult)
        printLine('');
        printLine(wrapHeader(header));
        printLine(thisResult);
    end
end
end

% LocalWords:  evd

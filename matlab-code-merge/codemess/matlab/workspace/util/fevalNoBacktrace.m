function fevalNoBacktrace(fcn)
%FEVALNOBACKTRACE Evaluate the function handle without a warning backtrace.

%   Copyright 2010 The MathWorks, Inc.

w = warning('query', 'backtrace');
warning('off', 'backtrace');

try
    fcn();
catch ME
    warning(w);
    rethrow(ME);
end

warning(w);

% [EOF]

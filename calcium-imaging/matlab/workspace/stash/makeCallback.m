function cb = makeCallback(fcn, varargin)
%MAKECALLBACK Define the MAKECALLBACK class.
%   OUT = MAKECALLBACK(ARGS) <long description>

%   Copyright 2013 The MathWorks, Inc.

cb = @(~,~) fcn(varargin{:});

% [EOF]

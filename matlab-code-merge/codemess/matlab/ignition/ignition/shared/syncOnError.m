function varargout = syncOnError(func, varargin)
%syncOnError Call a function on all labs, all labs error if one lab errors.

%   Copyright 2006-2012 The MathWorks, Inc.

err = false;
try
    [varargout{1:nargout}] = func(varargin{:});
catch exception
    err = true;
end
if gop(@or, err)
    labsThatFailed = [];
    if err
        labsThatFailed = labindex;
        returnedError = exception;
    end
    labsThatfailed = gcat(labsThatFailed);
    if ~err
        returnedError = MException(message(...
            'parallel:distributed:errorOnOtherLabs', num2str(labsThatfailed)));
    end
    throw(returnedError);
end

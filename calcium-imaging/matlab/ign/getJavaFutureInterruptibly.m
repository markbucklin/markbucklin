function value = getJavaFutureInterruptibly(future, shouldInterruptFcn, processEvents)
%getJavaFutureInterruptibly calls 'get' on a java future until it completes
%   VALUE = getJavaFutureInterruptibly(FUTURE) calls FUTURE.get(1, SECOND)
%   until such time that FUTURE yields a result. This is to allow users
%   to hit CTRL-C to abort. This function always cancels FUTURE on exit.
%
%   In the event that future.get() yields an ExecutionException, we attempt to
%   unpick that and throw the MessageID and LocalizedMessage if they exist.

% Copyright 2013-2015 The MathWorks, Inc.

if nargin < 2
    shouldInterruptFcn = @false;
end

if nargin < 3
    processEvents = false;
end

cancelFuture = onCleanup(@() future.cancel(true));
done = false;
value = [];
while ~done && ~shouldInterruptFcn()
    if processEvents
        drawnow;
    end
    [done, value] = parallel.internal.getJavaFutureResult(...
        future, 1, java.util.concurrent.TimeUnit.SECONDS);
end
end

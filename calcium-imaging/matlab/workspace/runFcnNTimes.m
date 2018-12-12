function allOut = runFcnNTimes( fcn, N, numOut)


if nargin < 3
    numOut = nargout(fcn);
end
out = cell(1,numOut);
allOut = cell(N,1);
k = 0;

while k < N
    k=k+1;
    if numOut >= 1
        [out{1:numOut}] = feval(fcn);
        allOut{k} = out;
    else
        feval(fcn);
    end
end



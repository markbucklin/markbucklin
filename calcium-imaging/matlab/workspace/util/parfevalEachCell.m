function [fut, tDispatch] = parfevalEachCell(fcnList)

pool = gcp;
tStart = tic;
tDispatch = nan(numel(fcnList),1);

for k=1:numel(fcnList)
	fcn = fcnList{k};
	numOut(k) = abs(nargout(fcn));
	fut(k) = parfeval(pool, fcn, numOut(k));
	tDispatch(k) = toc(tStart);
end
	
function f = lognorm(fIn)
% returns data greater than 0

fMax = max(max(max(fIn,[],1),[],2),[],3);
fMin = min(min(min(fIn,[],1),[],2),[],3);

if ~isfloat(fIn)
	f = single(fIn);
	fMax = single(fMax);
	fMin = single(fMin);
else
	f = fIn;
end



fRange = fMax - fMin;
f = bsxfun(@minus, f, fMin);
f = log( ...
	bsxfun(@rdivide,...
	fRange, ...
	abs(bsxfun(@minus, fRange, f))));
	

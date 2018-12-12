function f = expnorm(fIn)
warning('expnorm.m being called from scrap directory: Z:\Files\MATLAB\toolbox\ignition\scrap')


fMax = max(max(max(fIn,[],1),[],2),[],3);
fMin = min(min(min(fIn,[],1),[],2),[],3);

if ~isfloat(fIn)
	f = single(fIn);
	fMax = single(fMax);
	fMin = single(fMin);
else
	f = fIn;
end

expInvScale = cast(1/(1-exp(-1)), 'like', f);
expInvShift = cast(exp(-1), 'like', f);
fRange = fMax - fMin;
f = bsxfun(@minus, f, fMin);
f = expInvScale * (exp( - ...
	bsxfun(@rdivide,...
	bsxfun(@minus, fRange, f), ...
	fRange)) ...
	- expInvShift);
	

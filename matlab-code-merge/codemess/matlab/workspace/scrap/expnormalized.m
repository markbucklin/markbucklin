function f = expnormalized(fIn, timeDim)
warning('expnormalized.m being called from scrap directory: Z:\Files\MATLAB\toolbox\ignition\scrap')

if nargin < 2
	timeDim = 3;
end

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
	

% f = exp( -bsxfun(@rdivide,...
% 	bsxfun(@minus, fMax, single(f)), a));




% a = single(max(f,[],timeDim));
% f = exp( -bsxfun(@rdivide,...
% 	bsxfun(@minus, a, single(f)), a));
% fmin = min(min(min(f,[],1),[],2),[],timeDim);
% fmax = max(max(max(f,[],1),[],2),[],timeDim);
% f = bsxfun(@rdivide, bsxfun(@minus, f, fmin), fmax-fmin);


% f = exp( bsxfun(@rdivide,...
% 	bsxfun(@minus, single(f), a), a));

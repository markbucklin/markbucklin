function f = expnormalizedcomplement(f, timeDim)
warning('expnormalizedcomplement.m being called from scrap directory: Z:\Files\MATLAB\toolbox\ignition\scrap')

if nargin < 2
	timeDim = ndims(f);
end

if ~isfloat(f)
	f = single(f);
end
a = max(f,[],timeDim);

ainv = 1./abs(a+eps(a));
f = 1 - exp( bsxfun(@times, bsxfun(@minus, f, a), ainv));

% f = 1 - exp( bsxfun(@rdivide,...
% 	bsxfun(@minus, single(f), a), a));

fmin = min(min(min(f,[],1),[],2),[],timeDim);
fmax = max(max(max(f,[],1),[],2),[],timeDim);

frangeinv = 1./(fmax-fmin);
f = bsxfun(@times, bsxfun(@minus, f, fmin), frangeinv);

% f = bsxfun(@rdivide, bsxfun(@minus, f, fmin), fmax-fmin);


% f = exp( bsxfun(@rdivide,...
% 	bsxfun(@minus, single(f), a), a));

%  NEW EXPNORMALIZED FUNCTION
% function f = expnormalized(fIn, timeDim)
% 
% if nargin < 2
% 	timeDim = 3;
% end
% 
% fMax = max(max(max(fIn,[],1),[],2),[],3);
% fMin = min(min(min(fIn,[],1),[],2),[],3);
% 
% if ~isfloat(fIn)
% 	f = single(fIn);
% 	fMax = single(fMax);
% 	fMin = single(fMin);
% else
% 	f = fIn;
% end
% 
% expInvScale = cast(1/(1-exp(-1)), 'like', f);
% expInvShift = cast(exp(-1), 'like', f);
% fRange = fMax - fMin;
% f = bsxfun(@minus, f, fMin);
% f = expInvScale * (exp( - ...
% 	bsxfun(@rdivide,...
% 	bsxfun(@minus, fRange, f), ...
% 	fRange)) ...
% 	- expInvShift);

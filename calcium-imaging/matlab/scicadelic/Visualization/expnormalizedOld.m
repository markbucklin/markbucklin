function f = expnormalizedOld(f, timeDim)

if nargin < 2
	timeDim = 3;
end

a = single(max(f,[],timeDim));

f = exp( -bsxfun(@rdivide,...
	bsxfun(@minus, single(f), a), a));

fmin = min(min(min(f,[],1),[],2),[],timeDim);
fmax = max(max(max(f,[],1),[],2),[],timeDim);
f = bsxfun(@rdivide, bsxfun(@minus, f, fmin), fmax-fmin);


% f = exp( bsxfun(@rdivide,...
% 	bsxfun(@minus, single(f), a), a));

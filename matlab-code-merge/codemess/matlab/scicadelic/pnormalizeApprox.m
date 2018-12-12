function F = pnormalizeApprox(F, dim)
% Normalizes N-Dimensional array to values between 0 and 1 along one or more dimensions
%
% USAGE:
%	>> F = pnormalize(F, 1);
%	>> F = pnormalize(F, [1 2]);
if nargin < 2
	dim = 1;
end

if numel(dim) == 1
	F = bsxfun(@rdivide, bsxfun(@minus, F, min(F,[],dim)), range(F,dim));
else %if numel(dim) == 2
	Fmin = approximateFrameMinimum(F);
	Fmax = approximateFrameMaximum(F);
	Frange = Fmax - Fmin;
	F = bsxfun(@rdivide, bsxfun(@minus, F, Fmin), Frange);
	% else
	%    n = numel(dim);
	%    dimcell = num2cell(dim);
	%    Fmin = eval( sprintf([repmat('min(', 1,n), ' F ', repmat(', [], %i)',1,n)], dimcell{:}) );
	%    Fmax = eval( sprintf([repmat('max(', 1,n), ' F ', repmat(', [], %i)',1,n)], dimcell{:}) );
	%    Frange = Fmax - Fmin;
	%    F = bsxfun(@rdivide, bsxfun(@minus, F, Fmin), Frange);
end









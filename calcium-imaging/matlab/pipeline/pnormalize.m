function F = pnormalize(F, dim)
% Normalizes N-Dimensional array to values between 0 and 1 along one or more dimensions
%
% USAGE:
%	>> F = pnormalize(F, 1);
%	>> F = pnormalize(F, [1 2]);

% DEFAULT DIMENSION -> 1
if nargin < 2
   dim = 1;
end

% CONVERT F TO FLOATING POINT
if isinteger(F)
	F = single(F);
end

% APPLY NORMALIZATION BY SUBTRACTING MINIMUM AND DIVIDING BY RANGE ALONG GIVEN DIMENSION
if numel(dim) == 1
   F = bsxfun(@rdivide, bsxfun(@minus, F, min(F,[],dim)), range(F,dim));
else
   n = numel(dim);
   dimcell = num2cell(dim);
   Fmin = eval( sprintf([repmat('min(', 1,n), ' F ', repmat(', [], %i)',1,n)], dimcell{:}) );
   Fmax = eval( sprintf([repmat('max(', 1,n), ' F ', repmat(', [], %i)',1,n)], dimcell{:}) );
   Frange = Fmax - Fmin;
   F = bsxfun(@rdivide, bsxfun(@minus, F, Fmin), Frange);
end









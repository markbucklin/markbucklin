function F = znormalize(F, dim)
% Normalizes N-Dimensional array to values between 0 and 1 along one or more dimensions
%
% USAGE:
%	>> F = znormalize(F, 1);
%	>> F = znormalize(F, [1 2]);
if nargin < 2
   dim = 1;
end

if numel(dim) == 1
   F = bsxfun(@rdivide, bsxfun(@minus, F, mean(F,dim)), std(F,[],dim));
else
   n = numel(dim);
   dimcell = num2cell(dim);
   Fmean = eval( sprintf([repmat('mean(', 1,n), ' F ', repmat(', %i)',1,n)], dimcell{:}) );
   Fstd = eval( sprintf([repmat('std(', 1,n), ' F ', repmat(', [], %i)',1,n)], dimcell{:}) ); % not quite correct, but it'll do
   F = bsxfun(@rdivide, bsxfun(@minus, F, Fmean), Fstd);
end











% znormcol = @(v)bsxfun(@rdivide,bsxfun(@minus,v,mean(v,1)),std(v,[],1));
% znormrow = @(v)bsxfun(@rdivide,bsxfun(@minus,v,mean(v,2)),std(v,[],2));







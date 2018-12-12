function PX = binaryprob(x,dim)
if nargin < 2
   dim = 1;
end
PX = squeeze( bsxfun(@rdivide, sum(x,dim), size(x,1)));









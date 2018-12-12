function [f, varargout] = nanormize(f,dim)
f = single(f);
if nargin < 2
   dim = 1;
end
fnan = single(f);
fnan( bsxfun(@ge, f, median(f,dim)+std(f,[],dim))) = NaN;
f = bsxfun(@rdivide, bsxfun(@minus, f, nanmean(fnan,dim)), nanstd(fnan,dim));
if nargout > 1
   varargout{1} = fnan;
end
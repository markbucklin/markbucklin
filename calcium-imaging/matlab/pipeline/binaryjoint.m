function PXnY = binaryjoint(x,y)
% x = x(:);
% y = y(:);
if iscell(x)
   xcell = x;
   x = xcell{1};
   for k=1:numel(xcell)
	  x = bsxfun(@and, x, xcell{k});
   end
end
if iscell(y)
   ycell = y;
   y = ycell{1};
   for k=1:numel(ycell)
	  y = bsxfun(@and, y, ycell{k});
   end
end
% assert(size(x,1) == size(y,1), 'Input variables must have the same number of rows')
% assert(size(x,2)==1 || size(y,2)==1 || size(x,2)==size(y,2),...
%    'Input variables must have either the same number of columns, or one must be single-column')
% N = size(x,1);
if isequal(x,y) || isequal(x,~y)
   y = permute(shiftdim(y,-1), [2 1 3]);
end

PXnY = squeeze( bsxfun(@rdivide, sum(bsxfun(@and, x , y),1), size(x,1)));









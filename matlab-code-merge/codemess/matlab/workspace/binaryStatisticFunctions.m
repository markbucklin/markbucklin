function fh = binaryStatisticFunctions()


fh.P_X = @(x) binaryprob(x,1);
fh.P_XandX = @(x) binaryjoint(x,x);
fh.P_XgivenX = @(x) binaryconditional(x,x);
% fh.P_XandY = @(x,y) binaryjoint(x,y);
% fh.P_XgivenY = @(x,y) binaryconditional(x,y);


end




function PX = binaryprob(x,dim)
if nargin < 2
   dim = 1;
end
PX = double(squeeze( bsxfun(@rdivide, sum(x,dim), size(x,1))));
end
function PXnY = binaryjoint(x,y)
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
y = permute(shiftdim(y,-1), [2 1 3:(ndims(y)+1)]);
PXnY = squeeze( bsxfun(@rdivide, sum(bsxfun(@and, x , y),1), size(x,1)));
end
function PXIY = binaryconditional(x,y)
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
y = permute(shiftdim(y,-1), [2 1 3:(ndims(y)+1)]);
PXIY = squeeze(bsxfun(@rdivide, sum(bsxfun(@and, x , y),1) , sum(y,1)));
end


% 
% fh.P_X = @(x) binaryprob(x,1);
% fh.P_XandY = @(x) binaryjoint(num2cell(x,1));
% fh.P_XgivenY = @(x) binaryconditional(num2cell(x,1));
% 
% 
% end


% 
% function PX = binaryprob(x,dim)
% if nargin < 2
%    dim = 1;
% end
% PX = double(squeeze( bsxfun(@rdivide, sum(x,dim), size(x,1))));
% end
% function PXnY = binaryjoint(x,y)
% if nargin < 2
%     %     y = num2cell(x,1);
%     y = x;
% end
% if iscell(x)
%    xcell = x;
%    x = xcell{1};
%    for k=1:numel(xcell)
% 	  x = bsxfun(@and, x, xcell{k});
%    end
% end
% if iscell(y)
%    ycell = y;
%    y = ycell{1};
%    for k=1:numel(ycell)
% 	  y = bsxfun(@and, y, ycell{k});
%    end
% end
% y = permute(shiftdim(y,-1), [2 1 3:(ndims(y)+1)]);
% PXnY = squeeze( bsxfun(@rdivide, sum(bsxfun(@and, x , y),1), size(x,1)));
% end
% function PXIY = binaryconditional(x,y)
% if nargin < 2
%     y = x;
%     %     y = num2cell(x,1);
% end
% if iscell(x)
%    xcell = x;
%    x = xcell{1};
%    for k=1:numel(xcell)
% 	  x = bsxfun(@and, x, xcell{k});
%    end
% end
% if iscell(y)
%    ycell = y;
%    y = ycell{1};
%    for k=1:numel(ycell)
% 	  y = bsxfun(@and, y, ycell{k});
%    end
% end
% y = permute(shiftdim(y,-1), [2 1 3:(ndims(y)+1)]);
% PXIY = squeeze(bsxfun(@rdivide, sum(bsxfun(@and, x , y),1) , sum(y,1)));
% end
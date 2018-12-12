function xs = stackSurroundPixel(x, w, padVal)
warning('stackSurroundPixel.m being called from scrap directory: Z:\Files\MATLAB\toolbox\ignition\scrap')
% NOT YET FUNCTIONAL
if nargin < 3
	padVal = x(1,1);
	padVal(:) = 0;
	p = padVal;
else
	if isnan(padVal)
		padVal = x(1,1);
		padVal(:) = nan;
	elseif padVal == 1
		padVal = x(1,1);
		padVal(:) = 1;
	else
		padVal = x(1,1);
		padVal(:) = 0;
	end
	p = padVal;
end

edgePad = x(:,1:w);
edgePad(:) = p;

sz = size(x);
dim = ndims(x)+1;

xs = cat(dim, x,...
	padarray(x(w+1:end,:),[w 0],'replicate','pre'),...
	padarray(x(w+1:end,1:end-w),[w w],'replicate','pre'),...

padarray(x(w+1:end,w+1:end),[w w],'replicate','pre')
	


% 	cat(1, padval', x(1:end-w,:)),...
% 	cat(1,x(w+1:end,:),padval'),...

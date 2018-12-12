function C = frameCorrGpu(A, B, w)%, rowSubs, colSubs, frameSubs)
% FRAMECORR N-D correlation coefficient. w = optional weighting-matrix
% 8ms (no weight) vs 12ms (with weight)



% MANAGE INPUT ARGUMENTS -> DEFAULTS
[numRows, numCols, ~] = size(A);
numPixels = numRows*numCols;
if nargin < 2
	B = mean(A,3);
end
if nargin < 3
	% 	pixelWeight = gpuArray.ones(numRows, numCols, numFrames, 'double');
	w = [];
	% TODO: check ndims of Fref and permute 3rd dimension to one dimension greater than ndims(F)
end
% if nargin < 4
% 	rowSubs = gpuArray.colon(1,numRows)';
% 	colSubs = gpuArray.colon(1,numCols);
% 	frameSubs = reshape(gpuArray.colon(1, numFrames), 1,1,numFrames);
% end

if ~isempty(w)
	A = bsxfun(@times, double(A), double(w));
	B = bsxfun(@times, double(B), double(w));
end


% CALCULATE FRAME SUM
Asum = sum(sum(A, 1,'double'), 2);
Bsum = sum(sum(B, 1,'double'), 2);



[AB, AA, BB] = arrayfun(@findDotProducts, A, B, Asum, Bsum);

C = sum(sum(AB)) ./ sqrt(sum(sum(AA)).*sum(sum(BB)));












% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################
% 	function [sPxNew, pxPeak, pxBorder] = transitionDistKernel(rPx, sPx, rowC, colC, n)
	function [ab,aa,bb] = findDotProducts(a, b, aSum, bSum)
		%Nested function to compute (a-mean2(a)).*(b-mean2(b)),
		%(a-mean2(a))^2 and (b-mean2l(b))^2 element-wise.
		
		a = double(a) - aSum/numPixels;
		b = double(b) - bSum/numPixels;
		
		ab = a*b;
		aa = a*a;
		bb = b*b;
	end






end


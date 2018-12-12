function F = pnormalizeimage(F)
% Normalizes N-Dimensional stack of image frames to values between 0 and 1 
% (same as PNORMALIZE, but applies normalization over 1st & 2nd dimension by default)
%
% USAGE:
%	>> F = pnormalizeimage(F);



% CONVERT F TO FLOATING POINT
if isinteger(F)
	F = single(F);
end


% RESHAPE F 2D FRAMES TO COLUMNS
superDimensionProd = 1;
sz = size(F);
switch ndims(F)
	case 2
		[numRows, numCols] = size(F);
		numFrames = 1;
		numChannels = 1;
	case 3
		[numRows, numCols, numFrames] = size(F);
		numChannels = 1;
	case 4
		[numRows, numCols, numChannels, numFrames] = size(F);
	otherwise
		numRows = sz(1);
		numCols = sz(2);
		numChannels = sz(3);
		numCrames = sz(4);
		superDimensionProd = prod(sz(5:end));		
end
numPixels = numRows*numCols;
F = reshape(F, numPixels, numChannels*numFrames*superDimensionProd);


% APPLY NORMALIZATION BY SUBTRACTING MINIMUM AND DIVIDING BY RANGE IN EACH FRAME (COLUMN)
dim = 1;
F = bsxfun(@rdivide, bsxfun(@minus, F, min(F,[],dim)), range(F,dim));


% RETURN F TO ORIGINAL SHAPE
F = reshape(F, sz);

















% % DEFAULT DIMENSION -> 1,2
% dim = [1 2];
% 
% % CONVERT F TO FLOATING POINT
% if isinteger(F)
% 	F = single(F);
% end
% 
% % APPLY NORMALIZATION BY SUBTRACTING MINIMUM AND DIVIDING BY RANGE ALONG GIVEN DIMENSION
% if numel(dim) == 1
%    F = bsxfun(@rdivide, bsxfun(@minus, F, min(F,[],dim)), range(F,dim));
% else
%    n = numel(dim);
%    dimcell = num2cell(dim);
%    Fmin = eval( sprintf([repmat('min(', 1,n), ' F ', repmat(', [], %i)',1,n)], dimcell{:}) );
%    Fmax = eval( sprintf([repmat('max(', 1,n), ' F ', repmat(', [], %i)',1,n)], dimcell{:}) );
%    Frange = Fmax - Fmin;
%    F = bsxfun(@rdivide, bsxfun(@minus, F, Fmin), Frange);
% end







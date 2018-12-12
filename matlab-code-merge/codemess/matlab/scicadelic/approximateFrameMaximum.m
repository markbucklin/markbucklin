function pxMaxEstimate = approximateFrameMaximum(F, pctThresh)

if nargin < 2
	pctThresh = .05;
end
stepWidth = .3;
[numRows, numCols, dim3, dim4] = size(F);
numPixels = numRows*numCols;

% DETERMINE DIMENSION ORDERING SCHEME
if dim3 < 4
	numChannels = dim3;
	numFrames = dim4;
	colorDim = 3;
	timeDim = 4;
	
elseif dim4 < 4
	numChannels = dim4;
	numFrames = dim3;
	colorDim = 4;
	timeDim = 3;
	
else
	numChannels = min(dim3,dim4);
	numFrames = max(dim3,dim4);
	colorDim = 3*(dim3==numChannels) + 4*(dim3~=numChannels);
	timeDim = 3*(dim3==numFrames) + 4*(dim3~=numFrames);
end

% NEW: USE MEAN & MAX TO ESTIMATE GOOD REPRESENTATION OF DATA DISTRIBUTION
if numFrames > 1
	Fmean = mean(F,timeDim);
	Fmax = double( max(F, [], timeDim));
	Fmidway = .5*Fmean + .5*Fmax;
	Fpctgtmean = sum( bsxfun(@gt, F, Fmean), timeDim) ./ numFrames;
	Fpctgtmid = sum( bsxfun(@gt, F, Fmidway), timeDim) ./ numFrames;
	alpha = .5 + min(.5, Fpctgtmid);
	F = alpha.*Fmax + (1-alpha).*Fmean;
end

% INITIALIZE APPROXIMATION BY AVERAGING THE MAX TAKEN ALONG COLUMNS & ROWS SEPARATELY
actualMax = double(max(max(F,[],1),[],2));
colMax = max(F, [],1);
rowMax = max(F, [],2);
colIsNanInf = isnan(colMax(:)) | isinf(colMax(:));
rowIsNanInf = isnan(rowMax(:)) | isinf(rowMax(:));
if any(colIsNanInf)
	colMax = colMax(~colIsNanInf);
	rowMax = rowMax(~rowIsNanInf);
	actualMax = double(max( cat(1, colMax(:), rowMax(:))));
end
pxMaxEstimate = 1/2*mean(colMax, 2) + 1/2*mean(rowMax, 1);

% FIND NUMBER OF PIXELS IN EACH FRAME THAT EXCEED THAT VALUE
overCurrentMax = bsxfun(@gt, F, pxMaxEstimate);
pctOver = pnz(overCurrentMax);

% INCREASE APPROXIMATION ESTIMATE IN FRAMES WHERE SIGNIFICANT NUMBER OF PIXELS EXCEED CURRENT ESTIMATE
iter = 0;
pctOverThresh = bsxfun(@gt, pctOver , pctThresh);
while any(pctOverThresh(:)) && (iter < 10)
	
	% GENERATE NEW ESTIMATE BY STEPPING SOME FRACTION TOWARDS ACTUAL FRAME MAX
	dCurrentActual = bsxfun(@minus, double(actualMax), double(pxMaxEstimate));
	dStep = stepWidth .* bsxfun(@times, dCurrentActual, double(pctOverThresh));
	pxMaxEstimate = bsxfun(@plus, pxMaxEstimate, dStep);
	
	% 	pxStep = bsxfun(@plus, pxMaxEstimate, dStep);
	% 	pxMaxEstimate = mean(F(bsxfun(@gt, F, pxStep)));
	
	% EVALUATE NEW ESTIMATE SAME AS ABOVE
	overCurrentMax = bsxfun(@gt, F, pxMaxEstimate);
	pctOver = pnz(overCurrentMax);
	pctOverThresh = bsxfun(@gt, pctOver , pctThresh);
	iter = iter+1;
	
end



% NEWER VERSION FOR MULTIDIMENSIONAL OPERATION
% 	function fracNonZero = pnz(Fbw)
% 		% PERCENT-NON-ZERO
% 		% More accurately, this function returns the fraction of non-zeros.
% 		% Percentage is printed if no output is requested
% 		
% 		[numRows, numCols, ~, ~] = size(Fbw);
% 		numPixels = numRows*numCols;
% 		
% 		Nz = double( sum(uint32( sum(uint16( Fbw~=0 ), 1)) ,2));
% 		fracNonZero = bsxfun(@rdivide, Nz, double(numPixels));
% 		varargout{1} = fracNonZero;
% 		
% 	end


% function varargout = pnz(f)
% % PERCENT-NON-ZERO
% % More accurately, this function returns the fraction of non-zeros.
% % Percentage is printed if no output is requested
%
% N = numel(f);
% Nz = nnz(f);
% fracNonZero = double(Nz)/double(N);
%
% if nargout
% 	varargout{1} = fracNonZero;
% else
% 	fprintf('\t%3.3g%% \n',fracNonZero*100);
% end

function pxMinEstimate = approximateFrameMinimum(F, pctThresh)

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
	Fmin = double( min(F, [], timeDim));
	Fmidway = .5*Fmean + .5*Fmin;
	Fpctltmean = sum( bsxfun(@lt, F, Fmean), timeDim) ./ numFrames;
	Fpctltmid = sum( bsxfun(@lt, F, Fmidway), timeDim) ./ numFrames;
	alpha = 1 - min(.5, Fpctltmid);
	F = alpha.*Fmin + (1-alpha).*Fmean;
end

% INITIALIZE APPROXIMATION BY AVERAGING THE MAX TAKEN ALONG COLUMNS & ROWS SEPARATELY
actualMin = double(min(min(F,[],1),[],2));
colMin = min(F, [],1);
rowMin = min(F, [],2);
colIsNanInf = isnan(colMin(:)) | isinf(colMin(:));
rowIsNanInf = isnan(rowMin(:)) | isinf(rowMin(:));
if any(colIsNanInf)
	colMin = colMin(~colIsNanInf);
	rowMin = rowMin(~rowIsNanInf);
	actualMin = double(min( cat(1, colMin(:), rowMin(:))));
end
pxMinEstimate = 1/2*mean(colMin, 2) + 1/2*mean(rowMin, 1);

% FIND NUMBER OF PIXELS IN EACH FRAME THAT EXCEED THAT VALUE
underCurrentMin = bsxfun(@lt, F, pxMinEstimate);
pctUnder = pnz(underCurrentMin);

% INCREASE APPROXIMATION ESTIMATE IN FRAMES WHERE SIGNIFICANT NUMBER OF PIXELS EXCEED CURRENT ESTIMATE
iter = 0;
pctOverThresh = bsxfun(@lt, pctUnder , pctThresh);
while any(pctOverThresh(:)) && (iter < 10)
	
	% GENERATE NEW ESTIMATE BY STEPPING SOME FRACTION TOWARDS ACTUAL FRAME MAX
	dCurrentActual = bsxfun(@minus, double(actualMin), double(pxMinEstimate));
	dStep = stepWidth .* bsxfun(@times, dCurrentActual, double(pctOverThresh));
	pxMinEstimate = bsxfun(@plus, pxMinEstimate, dStep);
	
	% 	pxStep = bsxfun(@plus, pxMinEstimate, dStep);
	% 	pxMinEstimate = mean(F(bsxfun(@lt, F, pxStep)));
	
	% EVALUATE NEW ESTIMATE SAME AS ABOVE
	underCurrentMin = bsxfun(@lt, F, pxMinEstimate);
	pctUnder = pnz(underCurrentMin);
	pctOverThresh = bsxfun(@lt, pctUnder , pctThresh);
	iter = iter+1;
	
end








% 
% if nargin < 2
% 	pctThresh = .05;
% end
% stepWidth = .25;
% 
% actualMin = double(min(min(F,[],1),[],2));
% colMin = min(F, [],1);
% rowMin = min(F, [],2);
% pxMin = 1/2*mean(colMin, 2) + 1/2*mean(rowMin, 1);
% 
% underCurrentMin = bsxfun(@lt, F, pxMin);
% pctUnder = pnz(underCurrentMin);
% 
% iter = 0;
% while (pctUnder > pcThresh) && (iter < 10)
% 	dCurrentActual = bsxfun(@minus, pxMin, actualMin);
% 	dStep = dCurrentActual * stepWidth;
% 	pxStep = bsxfun(@minus, pxMin, dStep);
% 	pxMin = mean(F(bsxfun(@lt, F, pxStep)));
% 	
% 	underCurrentMin = bsxfun(@lt, F, pxMin);
% 	pctUnder = pnz(underCurrentMin);
% 	
% 	iter = iter+1;
% end



	

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

function [F, L, pdc] = localLabelSampler_exp(F, L, radiusRange, bThresh)
% Fast local contrast enhancement
% Samples pixels at distance estimated to be greater than 1 radius of the largest object (cell).
% Marks pixels as belonging to one of:
%			{
%			bright-foreground (cells)
%			dark-foreground (vessels)
%			background (neuropil)
%			}
%
%	INPUT:
%		F - [m,n] fluorescence intensity image, or [m,n,k] image stack -> gpuArray (underlying class: uint16)
%		sampleRadius - minumum distance in pixels that other pixels are sampled from for comparison
%		bThresh - minimum intensity difference between each pixel and sampled surround for difference to be considered significant and counted





% ==================================================
% RESHAPE MULTI-FRAME INPUT TO 2D
% ==================================================
[numRows, numCols, numFrames] = size(F);


% ==================================================
% FILL MISSING INPUTS WITH DEFAULTS
% ==================================================
if nargin < 2
	L = [];
end
if nargin < 3
	% 	radiusRange = 10;
	radiusRange = [4 16];
end
if nargin < 4
	bThresh = min(range(F,1),[],2);
end


% ==================================================
% SUBSCRIPTS INTO SHIFTED SURROUND
% ==================================================
rowSubs = gpuArray.colon(1,numRows)';
colSubs = gpuArray.colon(1,numCols);
frameSubs = reshape(gpuArray.colon(1, numFrames), 1,1,numFrames);


% ==================================================
% CALL HYBRID-MEDIAN-FILTER GPU KERNEL
% ==================================================
F = arrayfun( @hybridMedFilt,...
	rowSubs, colSubs, frameSubs);


% ==================================================
% CALL REGIONAL-DIFFERENCE-COUNTER GPU KERNEL
% ==================================================
numRegionalSamples = 4;
maxNumSamples = radiusRange(end)-radiusRange(1)+1;
if (maxNumSamples) > numRegionalSamples
	radiusSample = uint8(reshape(linspace(radiusRange(1), radiusRange(end), numRegionalSamples), 1,1,1,numRegionalSamples));
else
	radiusSample = uint8(reshape(radiusRange(1):radiusRange(end), 1,1,1,maxNumSamples));
end
pdc = sum(arrayfun( @countRegionalSignificantDifference,...
	F, rowSubs, colSubs, frameSubs, bThresh, radiusSample), 4);


% ==================================================
% INITIALIZE LABEL-MATRIX
% ==================================================
if isempty(L)
	[L, labelMax] = bwlabel(bwmorph(any(pdc>7,3),'close'));
else
	labelMax = max(L(:));
end


% ==================================================
% PROPAGATE LABEL-MATRIX
% ==================================================










% ##################################################
% STENCIL-OP SUB-FUNCTIONS -> RUNS ON GPU
% ##################################################

% ==================================================
% HYBRID MEDIAN FILTER
% ==================================================
	function curPx = hybridMedFilt( rowC, colC, n)
		
		% GET CURRENT/CENTER PIXEL FROM F (read-only)
		curPx = F(rowC, colC, n);
		
		% ------------------------------------------------
		% CALCULATE SUBSCRIPTS FOR ADJACENT/NEIGHBORING-PIXELS (8-CONNECTED)
		rowU = max( 1, rowC-1);
		rowD = min( numRows, rowC+1);
		colL = max( 1, colC-1);
		colR = min( numCols, colC+1);
		
		% GET IMMEDIATELY ADJACENT NEIGHBOR PIXELS
		adjPxUL = F(rowU, colL, n); % X
		adjPxUC = F(rowU, colC, n); % +
		adjPxUR = F(rowU, colR, n); % X
		adjPxDL = F(rowD, colL, n); % X
		adjPxDC = F(rowD, colC, n); % +
		adjPxDR = F(rowD, colR, n); % X
		adjPxCL = F(rowC, colL, n); % +
		adjPxCR = F(rowC, colR, n); % +
		
		% APPLY HYBRID MEDIAN FILTER (X+)
		if isinteger(adjPxUL)
			mmHV = bitshift( max(min(adjPxUC,adjPxDC),min(adjPxCL,adjPxCR)), -1) ...
				+ bitshift( min(max(adjPxUC,adjPxDC),max(adjPxCL,adjPxCR)), -1);
			mmXX = bitshift( max(min(adjPxUL,adjPxDL),min(adjPxUR,adjPxDR)), -1) ...
				+ bitshift( min(max(adjPxUL,adjPxDL),max(adjPxUR,adjPxDR)), -1);
		else
			mmHV = (max(min(adjPxUC,adjPxDC),min(adjPxCL,adjPxCR)) ...
				+ min(max(adjPxUC,adjPxDC),max(adjPxCL,adjPxCR))) / 2;
			mmXX = (max(min(adjPxUL,adjPxDL),min(adjPxUR,adjPxDR)) ...
				+ min(max(adjPxUL,adjPxDL),max(adjPxUR,adjPxDR))) / 2;
		end
		curPx = min( min(max(curPx,mmHV),max(curPx,mmXX)), max(mmHV,mmXX));
	end

% ==================================================
% REGIONAL SIGNIFICANT DIFFERENCE COUNT
% ==================================================
	function rcc = countRegionalSignificantDifference(curPx, rowC, colC, n, b, r)
		
		curPx_fp = single(curPx);
		% CALCULATE SUBSCRIPTS FOR SURROUNDING-PIXELS TO SAMPLE
		rowU = max( 1, rowC-r);
		rowD = min( numRows, rowC+r);
		colL = max( 1, colC-r);
		colR = min( numCols, colC+r);
		
		% COMPUTE DIFFERENCE BETWEEN CURRENT PIXEL & NON-LOCAL/REGIONAL SAMPLES
		regPxUL = curPx_fp - single(F(rowU, colL, n));
		regPxUC = curPx_fp - single(F(rowU, colC, n));
		regPxUR = curPx_fp - single(F(rowU, colR, n));
		regPxDL = curPx_fp - single(F(rowD, colL, n));
		regPxDC = curPx_fp - single(F(rowD, colC, n));
		regPxDR = curPx_fp - single(F(rowD, colR, n));
		regPxCL = curPx_fp - single(F(rowC, colL, n));
		regPxCR = curPx_fp - single(F(rowC, colR, n));
		
		% COUNT NUMBER & POLARITY OF SIGNIFICANT PIXEL INTENSITY DIFFERENCES
		rcc = int8(...
			sign(regPxUL) * single(abs(regPxUL)>b) ...
			+ sign(regPxUC) * single(abs(regPxUC)>b) ...
			+ sign(regPxUR) * single(abs(regPxUR)>b) ...
			+ sign(regPxCL) * single(abs(regPxCL)>b) ...
			+ sign(regPxCR) * single(abs(regPxCR)>b) ...
			+ sign(regPxDL) * single(abs(regPxDL)>b) ...
			+ sign(regPxDC) * single(abs(regPxDC)>b) ...
			+ sign(regPxDR) * single(abs(regPxDR)>b) );
	end



end


























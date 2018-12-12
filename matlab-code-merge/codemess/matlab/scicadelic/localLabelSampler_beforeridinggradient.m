function [F, P, rsdCount] = localLabelSampler(F, L, radiusRange, numRegionalSamples, bThresh)
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
if (nargin < 3) || isempty(radiusRange)
	% 	radiusRange = 10;
	radiusRange = [8 24];
end
if (nargin < 4) || isempty(numRegionalSamples)
	numRegionalSamples = 4;
end
if (nargin < 5) || isempty(bThresh)
	bThresh = fix(min(range(F,1),[],2) / 4);
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
	F, rowSubs, colSubs, frameSubs);


% ==================================================
% CALL REGIONAL-DIFFERENCE-COUNTER GPU KERNEL
% ==================================================
maxNumSamples = radiusRange(end)-radiusRange(1)+1;
if (maxNumSamples) > numRegionalSamples
	radiusSample = uint16(reshape(linspace(radiusRange(1), radiusRange(end), numRegionalSamples), 1,1,1,numRegionalSamples));
	actualNumSamples = numRegionalSamples;
else
	radiusSample = uint16(reshape(radiusRange(1):radiusRange(end), 1,1,1,maxNumSamples));
	actualNumSamples = maxNumSamples;
end
rsdCount = int16(sum(arrayfun( @countRegionalSignificantDifference,...
	F, rowSubs, colSubs, frameSubs, bThresh, radiusSample), 4));


% ==================================================
% INITIALIZE LABEL-MATRIX
% ==================================================
% if isempty(L)
% 	countThresh = actualNumSamples * 7;
% 	[L, labelMax] = bwlabel(bwmorph( sum(rsdCount>countThresh, 3) > (numFrames/2), 'close'));
% else
% 	labelMax = max(L(:));
% end


% ==================================================
% PROPAGATE LABELS VIA LABEL-CONFIDENCE CONSENSUS
% ==================================================
F = int16(bitshift(F,-1));
% Fsplit = int16(bitshift(uint16(F), -1)) .* fix(rsdCount/countThresh);
% [Fx,Fy,Ft] = gradient(Fsplit);
% pUnstable = abs(Fx)/mean(abs(Fx(:))) + abs(Fy)/mean(abs(Fy(:)));
% pUnstable = 1/2 * (single(abs(Fx))/max(single(abs(Fx(:)))) + single(abs(Fy))/max(single(abs(Fy(:)))));
% bw = rsdCount>26 & pUnstable<.1;
% [Fx,Fy,Ft] = gradient(int16(bitshift(F,-1));
% Fpack = typecast( 
P = arrayfun( @propagateLabelLikelihood,...
	F, rsdCount, rowSubs, colSubs, frameSubs);







% ##################################################
% STENCIL-OP SUB-FUNCTIONS -> RUNS ON GPU
% ##################################################

% ==================================================
% HYBRID MEDIAN FILTER
% ==================================================
	function fPx = hybridMedFilt(fPx, rowC, colC, n)
		
		% GET CURRENT/CENTER PIXEL FROM F (read-only)
		% 		fPx = F(rowC, colC, n)
		
		% ------------------------------------------------
		% CALCULATE SUBSCRIPTS FOR ADJACENT/NEIGHBORING-PIXELS (8-CONNECTED)
		rowU = max( 1, rowC-1);
		rowD = min( numRows, rowC+1);
		colL = max( 1, colC-1);
		colR = min( numCols, colC+1);		
		
		% GET IMMEDIATELY ADJACENT NEIGHBOR PIXELS
		fPxUL = F(rowU, colL, n); % X
		fPxUC = F(rowU, colC, n); % +
		fPxUR = F(rowU, colR, n); % X
		fPxDL = F(rowD, colL, n); % X
		fPxDC = F(rowD, colC, n); % +
		fPxDR = F(rowD, colR, n); % X
		fPxCL = F(rowC, colL, n); % +
		fPxCR = F(rowC, colR, n); % +
		
		% APPLY HYBRID MEDIAN FILTER (X+)
		if isinteger(fPxUL)
			mmHV = bitshift( max(min(fPxUC,fPxDC),min(fPxCL,fPxCR)), -1) ...
				+ bitshift( min(max(fPxUC,fPxDC),max(fPxCL,fPxCR)), -1);
			mmXX = bitshift( max(min(fPxUL,fPxDL),min(fPxUR,fPxDR)), -1) ...
				+ bitshift( min(max(fPxUL,fPxDL),max(fPxUR,fPxDR)), -1);
		else
			mmHV = (max(min(fPxUC,fPxDC),min(fPxCL,fPxCR)) ...
				+ min(max(fPxUC,fPxDC),max(fPxCL,fPxCR))) / 2;
			mmXX = (max(min(fPxUL,fPxDL),min(fPxUR,fPxDR)) ...
				+ min(max(fPxUL,fPxDL),max(fPxUR,fPxDR))) / 2;
		end
		fPx = min( min(max(fPx,mmHV),max(fPx,mmXX)), max(mmHV,mmXX));
	end

% ==================================================
% REGIONAL SIGNIFICANT DIFFERENCE COUNT
% ==================================================
	function rcc = countRegionalSignificantDifference(fPx, rowC, colC, n, b, r)
		
		fPx_fp = single(fPx);
		
		% CALCULATE SUBSCRIPTS FOR SURROUNDING-PIXELS TO SAMPLE
		rowU = max( 1, rowC-r);
		rowD = min( numRows, rowC+r);
		colL = max( 1, colC-r);
		colR = min( numCols, colC+r);
		
		% COMPUTE DIFFERENCE BETWEEN CURRENT PIXEL & NON-LOCAL/REGIONAL SAMPLES
		regPxUL = fPx_fp - single(F(rowU, colL, n));
		regPxUC = fPx_fp - single(F(rowU, colC, n));
		regPxUR = fPx_fp - single(F(rowU, colR, n));
		regPxDL = fPx_fp - single(F(rowD, colL, n));
		regPxDC = fPx_fp - single(F(rowD, colC, n));
		regPxDR = fPx_fp - single(F(rowD, colR, n));
		regPxCL = fPx_fp - single(F(rowC, colL, n));
		regPxCR = fPx_fp - single(F(rowC, colR, n));
		
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

% ==================================================
% LABEL-PROBABILITY ESTIMATION & PROPAGATION
% ==================================================
	function pll = propagateLabelLikelihood(fPx, cPx, rowC, colC, n)
		
		fPx = int16(fPx);
		
		% CALCULATE SUBSCRIPTS FOR SURROUNDING-PIXELS TO SAMPLE
		rowU = max( 1, rowC-1);
		rowD = min( numRows, rowC+1);
		colL = max( 1, colC-1);
		colR = min( numCols, colC+1);
		
		% GET IMMEDIATELY ADJACENT NEIGHBOR PIXEL INTENSITIES
		fPxUL = F(rowU, colL, n);
		fPxUC = F(rowU, colC, n);
		fPxUR = F(rowU, colR, n);
		fPxDL = F(rowD, colL, n);
		fPxDC = F(rowD, colC, n);
		fPxDR = F(rowD, colR, n);
		fPxCL = F(rowC, colL, n);
		fPxCR = F(rowC, colR, n);
		
		% ... AND REGIONAL-DIFFERENCE COUNTS
		cPxUL = rsdCount(rowU, colL, n);
		cPxUC = rsdCount(rowU, colC, n);
		cPxUR = rsdCount(rowU, colR, n);
		cPxDL = rsdCount(rowD, colL, n);
		cPxDC = rsdCount(rowD, colC, n);
		cPxDR = rsdCount(rowD, colR, n);
		cPxCL = rsdCount(rowC, colL, n);
		cPxCR = rsdCount(rowC, colR, n);
		
		% GET LOCAL FLUORESCENCE-INTENSITY GRADIENTS
		dfUC = fPxUC - fPx;
		dfUR = fPxUR - fPx;
		dfCR = fPxCR - fPx;
		dfDR = fPxDR - fPx;
		dfDC = fPxDC - fPx;
		dfDL = fPxDL - fPx;
		dfCL = fPxCL - fPx;
		dfUL = fPxUL - fPx;
		
		% GET SIGNIFICANT-DIFFERENCE-COUNT GRADIENTS
		dcUC = cPxUC - cPx;
		dcUR = cPxUR - cPx;
		dcCR = cPxCR - cPx;
		dcDR = cPxDR - cPx;
		dcDC = cPxDC - cPx;
		dcDL = cPxDL - cPx;
		dcCL = cPxCL - cPx;
		dcUL = cPxUL - cPx;
		
		% PEAK-PROBABILITY
		% 		pPeak = dcUC + dcUR + dcCR + dcDR + dcDC + dcDL + dcCL + dcUL;
		
		% GET RANGE & CONSISTENCY OF LOCAL GRADIENTS
		% 		dfMax = 2*max(max(max(max(max(max(max(...
		% 			abs(dfUC),abs(dfUR)),abs(dfCR)),abs(dfDR)),...
		% 			abs(dfDC)),abs(dfDL)),abs(dfCL)),abs(dfUL)); % (SOBEL)
		dfX = single((dfCR-dfCL)/2 + (dfUR-dfDL)/4 + (dfDR-dfUL)/2);
		dfY = single((dfDC-dfUC)/2 + (dfDR-dfUL)/4 + (dfDL-dfUR)/2);
		ndfX = dfX / max(abs(dfX),abs(dfY));
		ndfY = dfY / max(abs(dfX),abs(dfY));
		% 		dfDir = atan2(-dfY,dfX);
		
		dx = sign(dfX) .* single(abs(dfX)>2*abs(dfY));
		dy = sign(dfY) .* single(abs(dfY)>2*abs(dfX));
		
		
		
		% COUNT NUMBER & POLARITY OF SIGNIFICANT PIXEL INTENSITY DIFFERENCES
		
		pll = dfDir;
		
	end


end






% gradient -> [Fx,Fy,Ft] = gradient(single(F))		n8[10ms]  n2[6ms]		n4[7.5ms]
% gradient -> [Fx,Fy] = gradient(F)								n8[10ms]   t = 4.4 + 1.4n
% del2 ->			Dxy = del2(F)												n8[74ms]



% P = int8(...
% 			sign(regPxUL) * single(abs(regPxUL)>b) ...
% 			+ sign(regPxUC) * single(abs(regPxUC)>b) ...
% 			+ sign(regPxUR) * single(abs(regPxUR)>b) ...
% 			+ sign(regPxCL) * single(abs(regPxCL)>b) ...
% 			+ sign(regPxCR) * single(abs(regPxCR)>b) ...
% 			+ sign(regPxDL) * single(abs(regPxDL)>b) ...
% 			+ sign(regPxDC) * single(abs(regPxDC)>b) ...
% 			+ sign(regPxDR) * single(abs(regPxDR)>b) );















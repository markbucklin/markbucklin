function [R, varargout] = layerGenRunGpuKernel(F, regDiffThreshold, radialIdx, backgroundInput)
% SAMPLE SURROUND TO COMPUTE/UPDATE LAYER-PROBABILITY
% pixelLayerUpdate = samplePixelRegionRunGpuKernel(F, sigDiffThreshold, radiusSample, randomizeSample, rowSubs, colSubs, frameSubs)
%
% >> [R] = samplePixelRegionRunGpuKernel(F);
% >> [R,Flut] = samplePixelRegionRunGpuKernel(F);
% >> [R,RegMean,RegVar] = samplePixelRegionRunGpuKernel(F);
%
% NOTE: requesting the LUT more than doubles computation time.
% TODO: remove outlier rejection if it continues to show no difference


% ============================================================
% PROCESS INPUT - FILL DEFAULTS
% ============================================================
[numRows, numCols, numFrames, numChannels] = size(F);
rowSubs = int32(gpuArray.colon(1,numRows)');
colSubs = int32(gpuArray.colon(1,numCols));
frameSubs = int32(reshape(gpuArray.colon(1, numFrames), 1,1, numFrames));
chanSubs = int32(reshape(gpuArray.colon(1, numFrames), 1,1,1, numChannels));
numPixels = numRows*numCols;
if nargin < 5
	
	if nargin < 4
		backgroundInput = [];
		if nargin < 3
			radialIdx = [];
			if nargin < 2
				regDiffThreshold = [];
			end
		end
	end
end
if isempty(regDiffThreshold)
	regDiffThreshold = fix(mean(min(range(F,1),[],2),3)); % max(fix(min(range(F,1),[],2) / 4), [], 3);
end
if isempty(radialIdx)
	radialIdx = int32(gpuArray(reshape([3 8 12 24], 1,1,1,4)));
else
	radialIdx = int32(reshape(radialIdx, 1,1,1,numel(radialIdx)));
end
numSamples = numel(radialIdx);

% ============================================================
% FILTER BACKGROUND (normalize regional samples)
% ============================================================
if isempty(backgroundInput)
	backgroundSigma = 3;
	Fbg = gaussFiltFrameStack(F, backgroundSigma, [], 'symmetric');
else
	if isscalar(backgroundInput) || (numel(backgroundInput) < numPixels)
		backgroundSigma = oncpu(backgroundInput);
		Fbg = gaussFiltFrameStack(F, backgroundSigma, [], 'symmetric');
	else
		if numel(backgroundInput) == (numPixels*numFrames)
			Fbg = backgroundInput;
		else
			Fbg = repmat(backgroundInput, 1, 1, numFrames); % TODO: call distinct kernel instead
		end
	end
end



% ============================================================
% ALSO RETURN LUT-ENCODED? VALUE FOR MMI CALCULATION
% ============================================================
getAdditionalOutput = nargout>1;
getRegionalStats = nargout>2;





% ============================================================
% CALL SUB-FUNCTION USING GPU/ARRAYFUN (COMPILES CUDA KERNEL)
% ============================================================
sampleFraction = 1/single(8*numSamples);
if getAdditionalOutput
	if getRegionalStats
		[Rr, RegMean, RegVar] = arrayfun( @samplePixelRegionWithRegionalStats, F, rowSubs, colSubs, frameSubs, radialIdx, regDiffThreshold, sampleFraction);
		varargout{1} = mean(RegMean, 4);
		varargout{2} = mean(RegVar, 4);% not accurate actually
	else
		[Rr, Flut] = arrayfun( @samplePixelRegionWithLutKernel, F, rowSubs, colSubs, frameSubs, radialIdx, regDiffThreshold, sampleFraction);
		varargout{1} = Flut;
	end
else
	Rr = arrayfun( @samplePixelRegionKernel, F, rowSubs, colSubs, frameSubs, radialIdx, regDiffThreshold, sampleFraction);
end
R = sum(Rr, 4);











% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################
	function rCC = samplePixelRegionKernel(fCCuint16, rowC, colC, k, ridx, dfThresh, a)
		% NON-LUT-VERSION
		fCC = single(fCCuint16);
		
		% CALCULATE SUBSCRIPTS FOR SURROUNDING-PIXELS TO SAMPLE
		rowU = int32(max( 1, rowC-ridx));
		rowD = int32(min( numRows, rowC+ridx));
		colL = int32(max( 1, colC-ridx));
		colR = int32(min( numCols, colC+ridx));
		
		% RETRIEVE NON-LOCAL (REGIONAL) SAMPLES
		fUL = Fbg(rowU, colL, k);
		fUC = Fbg(rowU, colC, k);
		fUR = Fbg(rowU, colR, k);
		fCL = Fbg(rowC, colL, k);
		fCR = Fbg(rowC, colR, k);
		fDL = Fbg(rowD, colL, k);
		fDC = Fbg(rowD, colC, k);
		fDR = Fbg(rowD, colR, k);
		
		% COMPUTE DIFFERENCE BETWEEN CURRENT PIXEL & NON-LOCAL/REGIONAL SAMPLES
		dfUL = fCC - fUL;
		dfUC = fCC - fUC;
		dfUR = fCC - fUR;
		dfCL = fCC - fCL;
		dfCR = fCC - fCR;
		dfDL = fCC - fDL;
		dfDC = fCC - fDC;
		dfDR = fCC - fDR;
		
		% MITIGATE EFFECT OF OUTLIERS BY CAPPING/LIMITING REGIONAL-DIFFERENCES
		% 		df0 = ( min(abs(dfUL),abs(dfDR)) + min(abs(dfUR),abs(dfDL)) + min(abs(dfUC),abs(dfDC)) + min(abs(dfCL),abs(dfCR)) ) /4;
		% 		dfLim = 2*df0;
		% 		dfUL = sign(dfUL) * min(abs(dfUL), dfLim);
		% 		dfUC = sign(dfUC) * min(abs(dfUC), dfLim);
		% 		dfUR = sign(dfUR) * min(abs(dfUR), dfLim);
		% 		dfCL = sign(dfCL) * min(abs(dfCL), dfLim);
		% 		dfCR = sign(dfCR) * min(abs(dfCR), dfLim);
		% 		dfDL = sign(dfDL) * min(abs(dfDL), dfLim);
		% 		dfDC = sign(dfDC) * min(abs(dfDC), dfLim);
		% 		dfDR = sign(dfDR) * min(abs(dfDR), dfLim);
		
		% COMPUTE BASIC STATISTICS FOR INTENSITY VALUES FROM REGIONAL SAMPLE
		fGridMax = max(max(max(max(max(max(max(max(fCC,fUL),fUC),fUR),fCL),fCR),fDL),fDC),fDR);
		fGridMin = min(min(min(min(min(min(min(min(fCC,fUL),fUC),fUR),fCL),fCR),fDL),fDC),fDR);
		fGridRange = max(fGridMax - fGridMin, 1);
		fCCBright = 1 - (fGridMax - fCC)/fGridRange;
		fCCDark = 1 - (fCC - fGridMin)/fGridRange;
		
		% COUNT NUMBER & POLARITY OF SIGNIFICANT PIXEL INTENSITY DIFFERENCES
		rCC = single(...
			sign(dfUL) * single(abs(dfUL)>dfThresh) ...
			+ sign(dfUC) * single(abs(dfUC)>dfThresh) ...
			+ sign(dfUR) * single(abs(dfUR)>dfThresh) ...
			+ sign(dfCL) * single(abs(dfCL)>dfThresh) ...
			+ sign(dfCR) * single(abs(dfCR)>dfThresh) ...
			+ sign(dfDL) * single(abs(dfDL)>dfThresh) ...
			+ sign(dfDC) * single(abs(dfDC)>dfThresh) ...
			+ sign(dfDR) * single(abs(dfDR)>dfThresh) );
		
		% COMBINE INTENSITY-DIFFERENCE INFORMATION WITH COUNT-BASED PREDICTOR
		rCC = rCC*(fCCBright*single(rCC>0)) + rCC*(fCCDark*single(rCC<0));
		rCC = a*rCC;
		
	end
	function [rCC, fGridMean, fGridVar] = samplePixelRegionWithRegionalStats(fCCuint16, rowC, colC, k, ridx, dfThresh, a)
		% RETURN VALUES USED TO CALCULATE MEAN AND VARIANCE OF REGIONAL SAMPLES
		fCC = single(fCCuint16);
		
		% CALCULATE SUBSCRIPTS FOR SURROUNDING-PIXELS TO SAMPLE
		rowU = int32(max( 1, rowC-ridx));
		rowD = int32(min( numRows, rowC+ridx));
		colL = int32(max( 1, colC-ridx));
		colR = int32(min( numCols, colC+ridx));
		
		% RETRIEVE NON-LOCAL (REGIONAL) SAMPLES
		fUL = Fbg(rowU, colL, k);
		fUC = Fbg(rowU, colC, k);
		fUR = Fbg(rowU, colR, k);
		fCL = Fbg(rowC, colL, k);
		fCR = Fbg(rowC, colR, k);
		fDL = Fbg(rowD, colL, k);
		fDC = Fbg(rowD, colC, k);
		fDR = Fbg(rowD, colR, k);
		
		% COMPUTE DIFFERENCE BETWEEN CURRENT PIXEL & NON-LOCAL/REGIONAL SAMPLES
		dfUL = fCC - fUL;
		dfUC = fCC - fUC;
		dfUR = fCC - fUR;
		dfCL = fCC - fCL;
		dfCR = fCC - fCR;
		dfDL = fCC - fDL;
		dfDC = fCC - fDC;
		dfDR = fCC - fDR;
		
		% MITIGATE EFFECT OF OUTLIERS BY CAPPING/LIMITING REGIONAL-DIFFERENCES
		% 		df0 = ( min(abs(dfUL),abs(dfDR)) + min(abs(dfUR),abs(dfDL)) + min(abs(dfUC),abs(dfDC)) + min(abs(dfCL),abs(dfCR)) ) /4;
		% 		dfLim = 2*df0;
		% 		dfUL = sign(dfUL) * min(abs(dfUL), dfLim);
		% 		dfUC = sign(dfUC) * min(abs(dfUC), dfLim);
		% 		dfUR = sign(dfUR) * min(abs(dfUR), dfLim);
		% 		dfCL = sign(dfCL) * min(abs(dfCL), dfLim);
		% 		dfCR = sign(dfCR) * min(abs(dfCR), dfLim);
		% 		dfDL = sign(dfDL) * min(abs(dfDL), dfLim);
		% 		dfDC = sign(dfDC) * min(abs(dfDC), dfLim);
		% 		dfDR = sign(dfDR) * min(abs(dfDR), dfLim);
		
		% COMPUTE BASIC STATISTICS FOR INTENSITY VALUES FROM REGIONAL SAMPLE
		fGridMax = max(max(max(max(max(max(max(max(fCC,fUL),fUC),fUR),fCL),fCR),fDL),fDC),fDR);
		fGridMin = min(min(min(min(min(min(min(min(fCC,fUL),fUC),fUR),fCL),fCR),fDL),fDC),fDR);
		fGridRange = max(fGridMax - fGridMin, 1);
		fCCBright = 1 - (fGridMax - fCC)/fGridRange;
		fCCDark = 1 - (fCC - fGridMin)/fGridRange;
		
		% COMPUTE MEAN & VARIANCE
		fRegSum = fUL + fUC + fUR + fCL + fCR + fDL + fDC + fDR;
		fGridMean = single(.125) * fRegSum;
		fGridVar = single(.125) * ...
			( (fUL-fGridMean)^2 + (fUC-fGridMean)^2 + (fUR-fGridMean)^2 ...
			+ (fCL-fGridMean)^2 +														(fCR-fGridMean)^2 ...
			+ (fDL-fGridMean)^2 + (fDC-fGridMean)^2 + (fDR-fGridMean)^2);
		
		% COUNT NUMBER & POLARITY OF SIGNIFICANT PIXEL INTENSITY DIFFERENCES
		rCC = single(...
			sign(dfUL) * single(abs(dfUL)>dfThresh) ...
			+ sign(dfUC) * single(abs(dfUC)>dfThresh) ...
			+ sign(dfUR) * single(abs(dfUR)>dfThresh) ...
			+ sign(dfCL) * single(abs(dfCL)>dfThresh) ...
			+ sign(dfCR) * single(abs(dfCR)>dfThresh) ...
			+ sign(dfDL) * single(abs(dfDL)>dfThresh) ...
			+ sign(dfDC) * single(abs(dfDC)>dfThresh) ...
			+ sign(dfDR) * single(abs(dfDR)>dfThresh) );
		
		% COMBINE INTENSITY-DIFFERENCE INFORMATION WITH COUNT-BASED PREDICTOR
		rCC = rCC*(fCCBright*single(rCC>0)) + rCC*(fCCDark*single(rCC<0));
		rCC = a*rCC;
		
	end
	function [rCC, lutSignedSigDif] = samplePixelRegionWithLutKernel(fCCuint16, rowC, colC, k, ridx, dfThresh, a)
		% LUT-VERSION
		fCC = single(fCCuint16);
		
		% CALCULATE SUBSCRIPTS FOR SURROUNDING-PIXELS TO SAMPLE
		rowU = int32(max( 1, rowC-ridx));
		rowD = int32(min( numRows, rowC+ridx));
		colL = int32(max( 1, colC-ridx));
		colR = int32(min( numCols, colC+ridx));
		
		% RETRIEVE NON-LOCAL (REGIONAL) SAMPLES
		fUL = Fbg(rowU, colL, k);
		fUC = Fbg(rowU, colC, k);
		fUR = Fbg(rowU, colR, k);
		fCL = Fbg(rowC, colL, k);
		fCR = Fbg(rowC, colR, k);
		fDL = Fbg(rowD, colL, k);
		fDC = Fbg(rowD, colC, k);
		fDR = Fbg(rowD, colR, k);
		
		% COMPUTE DIFFERENCE BETWEEN CURRENT PIXEL & NON-LOCAL/REGIONAL SAMPLES
		dfUL = fCC - fUL;
		dfUC = fCC - fUC;
		dfUR = fCC - fUR;
		dfCL = fCC - fCL;
		dfCR = fCC - fCR;
		dfDL = fCC - fDL;
		dfDC = fCC - fDC;
		dfDR = fCC - fDR;
		
		% MITIGATE EFFECT OF OUTLIERS BY CAPPING/LIMITING REGIONAL-DIFFERENCES
		% 		df0 = ( min(abs(dfUL),abs(dfDR)) + min(abs(dfUR),abs(dfDL)) + min(abs(dfUC),abs(dfDC)) + min(abs(dfCL),abs(dfCR)) ) /4;
		% 		dfLim = 2*df0;
		% 		dfUL = sign(dfUL) * min(abs(dfUL), dfLim);
		% 		dfUC = sign(dfUC) * min(abs(dfUC), dfLim);
		% 		dfUR = sign(dfUR) * min(abs(dfUR), dfLim);
		% 		dfCL = sign(dfCL) * min(abs(dfCL), dfLim);
		% 		dfCR = sign(dfCR) * min(abs(dfCR), dfLim);
		% 		dfDL = sign(dfDL) * min(abs(dfDL), dfLim);
		% 		dfDC = sign(dfDC) * min(abs(dfDC), dfLim);
		% 		dfDR = sign(dfDR) * min(abs(dfDR), dfLim);
		
		% COMPUTE BASIC STATISTICS FOR INTENSITY VALUES FROM REGIONAL SAMPLE
		fGridMax = max(max(max(max(max(max(max(max(fCC,fUL),fUC),fUR),fCL),fCR),fDL),fDC),fDR);
		fGridMin = min(min(min(min(min(min(min(min(fCC,fUL),fUC),fUR),fCL),fCR),fDL),fDC),fDR);
		fGridRange = max(fGridMax - fGridMin, 1);
		fCCBright = 1 - (fGridMax - fCC)/fGridRange;
		fCCDark = 1 - (fCC - fGridMin)/fGridRange;
		
		% USE MEAN & STANDARD DEVIATION TO ENCODE LOW MEMORY VERSION OF COMPARATIVE INFORMATION
		fGridSum = fCC + fUL + fUC + fUR + fCL + fCR + fDL + fDC + fDR;
		fGridMean = single(1/9) * fGridSum;
		fGridStd = realsqrt( single(1/8) * ...
			( (fUL-fGridMean)^2 + (fUC-fGridMean)^2 + (fUR-fGridMean)^2 ...
			+ (fCL-fGridMean)^2 + (fCC-fGridMean)^2 + (fCR-fGridMean)^2 ...
			+ (fDL-fGridMean)^2 + (fDC-fGridMean)^2 + (fDR-fGridMean)^2));
		lutSignedSigDif = bitor( bitshift(...
			bitor(bitshift(uint16(abs(dfUL)>fGridStd), 7), ...
			bitor(bitshift(uint16(abs(dfUC)>fGridStd), 6), ...
			bitor(bitshift(uint16(abs(dfUR)>fGridStd), 5), ...
			bitor(bitshift(uint16(abs(dfCL)>fGridStd), 4), ...
			bitor(bitshift(uint16(abs(dfCR)>fGridStd), 3), ...
			bitor(bitshift(uint16(abs(dfDL)>fGridStd), 2), ...
			bitor(bitshift(uint16(abs(dfDC)>fGridStd), 1), ...
			bitshift(uint16(abs(dfDR)>fGridStd), 0)))))))), 8),...
			bitor(bitshift(uint16(sign(dfUL)>0), 7), ...
			bitor(bitshift(uint16(sign(dfUC)>0), 6), ...
			bitor(bitshift(uint16(sign(dfUR)>0), 5), ...
			bitor(bitshift(uint16(sign(dfCL)>0), 4), ...
			bitor(bitshift(uint16(sign(dfCR)>0), 3), ...
			bitor(bitshift(uint16(sign(dfDL)>0), 2), ...
			bitor(bitshift(uint16(sign(dfDC)>0), 1), ...
			bitshift(uint16(sign(dfDR)>0), 0)))))))));
		
		% COUNT NUMBER & POLARITY OF SIGNIFICANT PIXEL INTENSITY DIFFERENCES
		rCC = single(...
			sign(dfUL) * single(abs(dfUL)>dfThresh) ...
			+ sign(dfUC) * single(abs(dfUC)>dfThresh) ...
			+ sign(dfUR) * single(abs(dfUR)>dfThresh) ...
			+ sign(dfCL) * single(abs(dfCL)>dfThresh) ...
			+ sign(dfCR) * single(abs(dfCR)>dfThresh) ...
			+ sign(dfDL) * single(abs(dfDL)>dfThresh) ...
			+ sign(dfDC) * single(abs(dfDC)>dfThresh) ...
			+ sign(dfDR) * single(abs(dfDR)>dfThresh) );
		
		% COMBINE INTENSITY-DIFFERENCE INFORMATION WITH COUNT-BASED PREDICTOR
		rCC = rCC*(fCCBright*single(rCC>0)) + rCC*(fCCDark*single(rCC<0));
		rCC = a*rCC;
		
	end
end


















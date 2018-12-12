function [R, varargout] = samplePixelRegionRunGpuKernel(F, regDiffThreshold, radialIdx, randomizeRegion, rowSubs, colSubs, frameSubs)
% SAMPLE SURROUND TO COMPUTE/UPDATE LAYER-PROBABILITY
% pixelLayerUpdate = samplePixelRegionRunGpuKernel(F, sigDiffThreshold, radiusSample, randomizeSample, rowSubs, colSubs, frameSubs)
%
% >> [R] = samplePixelRegionRunGpuKernel(F);
% >> [R,Flut] = samplePixelRegionRunGpuKernel(F);
% >> [R,RegMean,RegVar] = samplePixelRegionRunGpuKernel(F);
%
% NOTE: requesting the LUT more than doubles computation time.



% ============================================================
% PROCESS INPUT - FILL DEFAULTS
% ============================================================
[numRows, numCols, numFrames] = size(F);
if nargin < 5
	rowSubs = int32(gpuArray.colon(1,numRows)');
	colSubs = int32(gpuArray.colon(1,numCols));
	frameSubs = int32(reshape(gpuArray.colon(1, numFrames), 1,1,numFrames));
	if nargin < 4
		randomizeRegion = gpuArray.false(1);
		if nargin < 3
			radialIdx = [];
			if nargin < 2
				regDiffThreshold = [];
			end
		end
	end
end
if isempty(regDiffThreshold)
	regDiffThreshold = max(fix(min(range(F,1),[],2) / 4), [], 3);
end
if isempty(radialIdx)
	radialIdx = int32(gpuArray(reshape([3 8 12 24], 1,1,1,4)));
else
	radialIdx = int32(reshape(radialIdx, 1,1,1,numel(radialIdx)));
end
numSamples = numel(radialIdx);


% ============================================================
% ALSO RETURN LUT-ENCODED? VALUE FOR MMI CALCULATION
% ============================================================
getAdditionalOutput = nargout>1;
getRegionalStats = nargout>2;


% ============================================================
% RANDOMIZE SAMPLING-DISTANCES IF SPECIFIED
% ============================================================
% (generates a single randomized radius for each frame to maintain coalescing memory access... not ideal but faster)
if randomizeRegion
	if (numSamples>1)
		randRange = floor(min(abs(diff(radialIdx(:))))/2);
		randDev = gpuArray.randi([-randRange randRange], 1, 1, numFrames, numSamples-1, 'int32');
		radialIdx = cat(4, ...
			repmat(radialIdx(:,:,:,1), 1,1,numFrames,1), ...
			bsxfun(@plus, radialIdx(:,:,:,2:end), randDev));
	else
		randRange = floor(abs(radialIdx(1)/2));
		randDev = gpuArray.randi([-randRange randRange], 1, 1, numFrames, 1, 'int32');
		radialIdx = bsxfun(@plus, radialIdx, randDev);
	end
end


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
		fUL = single(F(rowU, colL, k));
		fUC = single(F(rowU, colC, k));
		fUR = single(F(rowU, colR, k));
		fCL = single(F(rowC, colL, k));
		fCR = single(F(rowC, colR, k));
		fDL = single(F(rowD, colL, k));
		fDC = single(F(rowD, colC, k));
		fDR = single(F(rowD, colR, k));
		
		% COMPUTE DIFFERENCE BETWEEN CURRENT PIXEL & NON-LOCAL/REGIONAL SAMPLES
		dfUL = fCC - fUL;
		dfUC = fCC - fUC;
		dfUR = fCC - fUR;
		dfCL = fCC - fCL;
		dfCR = fCC - fCR;
		dfDL = fCC - fDL;
		dfDC = fCC - fDC;
		dfDR = fCC - fDR;
		
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
		fUL = single(F(rowU, colL, k));
		fUC = single(F(rowU, colC, k));
		fUR = single(F(rowU, colR, k));
		fCL = single(F(rowC, colL, k));
		fCR = single(F(rowC, colR, k));
		fDL = single(F(rowD, colL, k));
		fDC = single(F(rowD, colC, k));
		fDR = single(F(rowD, colR, k));
		
		% COMPUTE DIFFERENCE BETWEEN CURRENT PIXEL & NON-LOCAL/REGIONAL SAMPLES
		dfUL = fCC - fUL;
		dfUC = fCC - fUC;
		dfUR = fCC - fUR;
		dfCL = fCC - fCL;
		dfCR = fCC - fCR;
		dfDL = fCC - fDL;
		dfDC = fCC - fDC;
		dfDR = fCC - fDR;
		
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
			( realpow(fUL-fGridMean,2) + realpow(fUC-fGridMean,2) + realpow(fUR-fGridMean,2) ...
			+ realpow(fCL-fGridMean,2) +														realpow(fCR-fGridMean,2) ...
			+ realpow(fDL-fGridMean,2) + realpow(fDC-fGridMean,2) + realpow(fDR-fGridMean,2));
		
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
		fUL = single(F(rowU, colL, k));
		fUC = single(F(rowU, colC, k));
		fUR = single(F(rowU, colR, k));
		fCL = single(F(rowC, colL, k));
		fCR = single(F(rowC, colR, k));
		fDL = single(F(rowD, colL, k));
		fDC = single(F(rowD, colC, k));
		fDR = single(F(rowD, colR, k));
		
		% COMPUTE DIFFERENCE BETWEEN CURRENT PIXEL & NON-LOCAL/REGIONAL SAMPLES
		dfUL = fCC - fUL;
		dfUC = fCC - fUC;
		dfUR = fCC - fUR;
		dfCL = fCC - fCL;
		dfCR = fCC - fCR;
		dfDL = fCC - fDL;
		dfDC = fCC - fDC;
		dfDR = fCC - fDR;
		
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
			( realpow(fUL-fGridMean,2) + realpow(fUC-fGridMean,2) + realpow(fUR-fGridMean,2) ...
			+ realpow(fCL-fGridMean,2) + realpow(fCC-fGridMean,2) + realpow(fCR-fGridMean,2) ...			 
			+ realpow(fDL-fGridMean,2) + realpow(fDC-fGridMean,2) + realpow(fDR-fGridMean,2)));
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



















% CALCULATE SUBSCRIPTS FOR SURROUNDING-PIXELS TO SAMPLE ( wrap or rail --> rail ~ 10% faster)
% rowU = bitand(int32(rowC)-1-r , int32(numRows)-1) + 1;
% rowD = bitand(int32(rowC)-1+r , int32(numRows)-1) + 1;
% colL = bitand(int32(colC)-1-r , int32(numCols)-1) + 1;
% colR = bitand(int32(colC)-1+r , int32(numCols)-1) + 1;













function P = updatePixelLayerRunGpuKernel(F, sigDiffThreshold, radiusSample, randomizeSample, rowSubs, colSubs, frameSubs)
% SAMPLE SURROUND TO COMPUTE/UPDATE LAYER-PROBABILITY
% pixelLayerUpdate = updatePixelLayerRunGpuKernel(F, sigDiffThreshold, radiusSample, randomizeSample, rowSubs, colSubs, frameSubs)



% ============================================================
% PROCESS INPUT - FILL DEFAULTS
% ============================================================
[numRows, numCols, numFrames] = size(F);
if nargin < 5
	rowSubs = gpuArray.colon(1,numRows)';
	colSubs = gpuArray.colon(1,numCols);
	frameSubs = reshape(gpuArray.colon(1, numFrames), 1,1,numFrames);	
	if nargin < 4
		randomizeSample = false;		
		if nargin < 3
			radiusSample = [];			
			if nargin < 2
				sigDiffThreshold = [];
			end
		end
	end
end
if isempty(sigDiffThreshold)
	sigDiffThreshold = max(fix(min(range(F,1),[],2) / 4), [], 3);
end
if isempty(radiusSample)
	radiusSample = reshape([2 8 12 24], 1,1,1,4);
else
	radiusSample = reshape(radiusSample, 1,1,1,numel(radiusSample));
end
numSamples = numel(radiusSample);



% ============================================================
% RANDOMIZE SAMPLING-DISTANCES IF SPECIFIED 
% ============================================================
% (generates a single randomized radius for each frame to maintain coalescing memory access... not ideal but faster)
if randomizeSample
	randRange = int16(floor(min(abs(diff(radiusSample(:))))/2));
	randDev = gpuArray.randi([-randRange randRange], 1, 1, numFrames, numSamples, 'int16');
	radiusSample = bsxfun(@plus, int16(radiusSample), randDev);
else
	radiusSample = int16(radiusSample);
end



% ============================================================
% CALL SUB-FUNCTION USING GPU/ARRAYFUN (COMPILES CUDA KERNEL)
% ============================================================
sampleFraction = 1/single(8*numSamples);
Psample = arrayfun( @updatePixelLayerKernel, F, rowSubs, colSubs, frameSubs, radiusSample, sigDiffThreshold, sampleFraction);
P = sum(Psample, 4);









% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################
	function pPx = updatePixelLayerKernel(fPxInt, rowC, colC, k, r, dfThresh, a)
		
		fPx = single(fPxInt);
		
		% CALCULATE SUBSCRIPTS FOR SURROUNDING-PIXELS TO SAMPLE ( wrap or rail --> rail ~ 10% faster)
		% 		rowU = mod(int16(rowC)-r , int16(numRows)) + 1;
		% 		rowD = mod(int16(rowC)+r , int16(numRows)) + 1;
		% 		colL = mod(int16(colC)-r , int16(numCols)) + 1;
		% 		colR = mod(int16(colC)+r , int16(numCols)) + 1;
		rowU = int16(max( 1, rowC-r));
		rowD = int16(min( numRows, rowC+r));
		colL = int16(max( 1, colC-r));
		colR = int16(min( numCols, colC+r));
		
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
		dfUL = fPx - fUL;
		dfUC = fPx - fUC;
		dfUR = fPx - fUR;
		dfCL = fPx - fCL;
		dfCR = fPx - fCR;
		dfDL = fPx - fDL;
		dfDC = fPx - fDC;
		dfDR = fPx - fDR;
		
		% COMPUTE BASIC STATISTICS FOR INTENSITY VALUES FROM REGIONAL SAMPLE		
		fGridMax = max(max(max(max(max(max(max(max(fPx,fUL),fUC),fUR),fCL),fCR),fDL),fDC),fDR);
		fGridMin = min(min(min(min(min(min(min(min(fPx,fUL),fUC),fUR),fCL),fCR),fDL),fDC),fDR);
		fGridRange = max(fGridMax - fGridMin, 1);
		fPxBright = 1 - (fGridMax - fPx)/fGridRange;
		fPxDark = 1 - (fPx - fGridMin)/fGridRange;
		
		% USE MEAN & STANDARD DEVIATION TO ENCODE LOW MEMORY VERSION OF COMPARATIVE INFORMATION
		fGridSum = fPx + fUL + fUC + fUR + fCL + fCR + fDL + fDC + fDR;
		fGridMean = single(1/9) * fGridSum;
		fGridStd = realsqrt( single(1/8) * ...
			( realpow(fPx-fGridMean,2) + realpow(fCL-fGridMean,2) + realpow(fCL-fGridMean,2) ...
			+ realpow(fUL-fGridMean,2) + realpow(fUC-fGridMean,2) + realpow(fUR-fGridMean,2) ...
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
		pPx = single(...
			sign(dfUL) * single(abs(dfUL)>dfThresh) ...
			+ sign(dfUC) * single(abs(dfUC)>dfThresh) ...
			+ sign(dfUR) * single(abs(dfUR)>dfThresh) ...
			+ sign(dfCL) * single(abs(dfCL)>dfThresh) ...
			+ sign(dfCR) * single(abs(dfCR)>dfThresh) ...
			+ sign(dfDL) * single(abs(dfDL)>dfThresh) ...
			+ sign(dfDC) * single(abs(dfDC)>dfThresh) ...
			+ sign(dfDR) * single(abs(dfDR)>dfThresh) );
		
		% COMBINE INTENSITY-DIFFERENCE INFORMATION WITH COUNT-BASED PREDICTOR
		pPx = pPx*(fPxBright*single(pPx>0)) + pPx*(fPxDark*single(pPx<0));
		pPx = a*pPx;
		% 		pPx = pPx / (8*n);
		
	end
end











% rowU = bitand(int16(rowC)-1-r , int16(numRows)-1) + 1;
% rowD = bitand(int16(rowC)-1+r , int16(numRows)-1) + 1;
% colL = bitand(int16(colC)-1-r , int16(numCols)-1) + 1;
% colR = bitand(int16(colC)-1+r , int16(numCols)-1) + 1;













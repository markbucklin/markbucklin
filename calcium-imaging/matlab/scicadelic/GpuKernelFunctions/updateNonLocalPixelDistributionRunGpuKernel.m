function [nlM1, nlM2, nlM3, nlM4, N] = updateNonLocalPixelDistributionRunGpuKernel(F, radialIdx)
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
[numRows, numCols, numFrames, numChannels] = size(F);
rowSubs = int32(gpuArray.colon(1,numRows)');
colSubs = int32(gpuArray.colon(1,numCols));
frameSubs = int32(reshape(gpuArray.colon(1, numFrames), 1,1,numFrames));
chanSubs =  int32(reshape(gpuArray.colon(1, numChannels), 1,1,1,numChannels));
if nargin < 2
	radialIdx = [];
end

if isempty(radialIdx)
	radialIdx = int32(gpuArray([8 16 24]));
% 	radialIdx = int32(gpuArray(reshape([8 16 24], 1,1,1,1,3)));
% else
% 	radialIdx = int32(reshape(radialIdx, 1,1,1,1,numel(radialIdx)));
end

xDirIdx = int32(reshape([-1 1], 1,1,1,1,1,2));

numSamples = numel(radialIdx);



% ============================================================
% RANDOMIZE SAMPLING-DISTANCES IF SPECIFIED
% ============================================================
% (generates a single randomized radius for each frame to maintain coalescing memory access... not ideal but faster)

randRange = floor(min(abs(diff(radialIdx(:))))/2);
randDev = gpuArray.randi([-randRange randRange], 1, 1, numFrames, 1, numSamples, 'int32');
radialIdx = bsxfun(@plus, radialIdx(:,:,:,2:end), randDev);



% ============================================================
% CALL SUB-FUNCTION USING GPU/ARRAYFUN (COMPILES CUDA KERNEL)
% ============================================================

[nlM1, nlM2] = arrayfun( @nonLocalPixelDistributionKernelFcn, rowSubs, colSubs, chanSubs);














% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################
	function [fGridMean, fGridVar] = nonLocalPixelDistributionKernelFcn(rowC, colC, chanC)
		
		% RETURN VALUES USED TO CALCULATE MEAN AND VARIANCE OF REGIONAL SAMPLES
		fCC = single(F(rowC,colC,k,chanC));
		
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
			( (fUL-fGridMean)^2 + (fUC-fGridMean)^2 + (fUR-fGridMean)^2 ...
			+ (fCL-fGridMean)^2 +											(fCR-fGridMean)^2 ...
			+ (fDL-fGridMean)^2 + (fDC-fGridMean)^2 + (fDR-fGridMean)^2);
		
		
	end
end



















% CALCULATE SUBSCRIPTS FOR SURROUNDING-PIXELS TO SAMPLE ( wrap or rail --> rail ~ 10% faster)
% rowU = bitand(int32(rowC)-1-r , int32(numRows)-1) + 1;
% rowD = bitand(int32(rowC)-1+r , int32(numRows)-1) + 1;
% colL = bitand(int32(colC)-1-r , int32(numCols)-1) + 1;
% colR = bitand(int32(colC)-1+r , int32(numCols)-1) + 1;













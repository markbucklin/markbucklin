function A = temporalStabilityRunGpuKernel(F, F0)
% temporalStabilityRunGpuKernel
%
%
% SEE ALSO:
%			
%
% Mark Bucklin





% ============================================================
% INFO ABOUT INPUT
% ============================================================
[numRows,numCols,numFrames,numChannels] = size(F);
rowSubs = int32(gpuArray.colon(1,numRows)');
colSubs = int32(gpuArray.colon(1,numCols));
frameSubs = int32(reshape(gpuArray.colon(1, numFrames), 1,1,numFrames));
chanSubs =  int32(reshape(gpuArray.colon(1, numChannels), 1,1,1,numChannels));



if (nargin < 2)
% 	F0 = single(mean(F,3));
	F0 = uint16(mean(F,3));
end
	
% [difMean,difMax] = arrayfun(@statUpdateLoopInternalKernelFcn, Fbuf, rowSubs, colSubs, frameSubs, chanSubs);
A = arrayfun(@normalizedSpatialGradientMagnitudeKernelFcn, F0, rowSubs, colSubs, chanSubs);














% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################



% ============================================================
% LOOP-INSIDE-KERNEL
% ============================================================
% [fMin,fMax,fM1,fM2,fM3,fM4,N] = arrayfun(@statUpdateLoopInternalKernelFcn, rowSubs, colSubs, Na, chanSubs);
% 	function [fmin,fmax,m1,m2,m3,m4,n] = temporalStabilityKernelFcn(f0, rowC, colC, frameC, chanC)
% 		function a = normalizedSpatialGradientMagnitudeKernelFcn(fIn, rowC, colC, frameC, chanC)
	function a = normalizedSpatialGradientMagnitudeKernelFcn(fIn, rowC, colC, chanC)
		
			f = single(fIn);
			frameC = int32(1);
			
			% CALCULATE SUBSCRIPTS FOR SURROUNDING (NEIGHBOR) PIXELS
			rowU = int32(max( 1, rowC-1));
			rowD = int32(min( numRows, rowC+1));
			colL = int32(max( 1, colC-1));
			colR = int32(min( numCols, colC+1));
			
			% RETRIEVE NEIGHBOR PIXEL INTENSITY VALUES
			fUL = single(F0(rowU, colL, frameC, chanC));
			fUC = single(F0(rowU, colC, frameC, chanC));
			fUR = single(F0(rowU, colR, frameC, chanC));
			fCL = single(F0(rowC, colL, frameC, chanC));
			fCR = single(F0(rowC, colR, frameC, chanC));
			fDL = single(F0(rowD, colL, frameC, chanC));
			fDC = single(F0(rowD, colC, frameC, chanC));
			fDR = single(F0(rowD, colR, frameC, chanC));
			
			% COMPUTE DIFFERENCE BETWEEN CURRENT PIXEL & NEIGHBORING SAMPLES
			dfUL = f - fUL;
			dfUC = f - fUC;
			dfUR = f - fUR;
			dfCL = f - fCL;
			dfCR = f - fCR;
			dfDL = f - fDL;
			dfDC = f - fDC;
			dfDR = f - fDR;
			
			% COMPUTE MEAN & VARIANCE
			fNeighSum = fUL + fUC + fUR + fCL + fCR + fDL + fDC + fDR;
			fNeighMean = single(1/8) * fNeighSum;
			
			meanSpatialDiff = single(1/8) * ( single(0) ...
				+ abs(dfUL) + abs(dfUC) + abs(dfUR) ...
				+ abs(dfCL) 						+	abs(dfCR) ...
				+ abs(dfDL) + abs(dfDC) + abs(dfDR) );
						
			
			a = meanSpatialDiff/fNeighMean; % max(0,f-fNeighMean)/fNeighMean;
		
		end



end








% 			out1 = dfNeighMax/fNeighMax;
% 			out2 = meanSpatialDiff/fNeighMax;

	
% 			
% 			
% 			
% 			
% 			dfMax = single(0);
% 			dfMin = single(0);
% 			dfSum = single(0);
% 			fkm1 = fCC;
% 			dfkm1 = single(0);			
% 			k = 0;
% 			while k < numFrames
% 				
% 				% UPDATE SAMPLE INDICES (USUALLY TEMPORAL)
% 				k = k + 1;				
% 				
% 				% GET PIXEL SAMPLE
% 				fk = single(F(rowC,colC,k,chanC));				
% 				
% 				% UPDATE MIN/MAX				
% 				dfk = (fk - fkm1)/max(fk,fCC);
% 				dfMax = max( dfMax, dfk);
% 				dfMin = min( dfMin, dfk);
% 				dfSum = dfSum + abs(dfk-dfkm1);
% 				
% 				fkm1 = fk;
% 				dfkm1 = dfk;
% 				
% 				% 				dk = d/n;
% 				% 				dk2 = dk^2;
% 				% 				s = d*dk*(n-1);
% 				% 				m1 = m1 + dk;
% 				% 				m4 = m4 + s*dk2*(n^2-3*n+3) + 6*dk2*m2 - 4*dk*m3;
% 				% 				m3 = m3 + s*dk*(n-2) - 3*dk*m2;
% 				% 				m2 = m2 + s;
% 			end
% 			
% 			dfRange = (dfMax - dfMin)/max(dfMax,-dfMin);
% 			dfMean = dfSum/single(numFrames);
% 			


% COMPUTE BASIC STATISTICS FOR INTENSITY VALUES
% fNeighMax = max(max(max(max(max(max(max(max(f,fUL),fUC),fUR),fCL),fCR),fDL),fDC),fDR);
% fNeighMin = min(min(min(min(min(min(min(min(f,fUL),fUC),fUR),fCL),fCR),fDL),fDC),fDR);
% fNeighRange = max(fNeighMax - fNeighMin, 1);
% 
% fBright = 1 - (fNeighMax - f)/fNeighRange;
% fDark = 1 - (f - fNeighMin)/fNeighRange;
% 
% 
% % COMPUTE BASIC STATISTICS FOR INTENSITY VALUES
% dfNeighMax = max(max(max(max(max(max(max(abs(dfUL),abs(dfUC)),abs(dfUR)),abs(dfCL)),abs(dfCR)),abs(dfDL)),abs(dfDC)),abs(dfDR));
% dfNeighMin = min(min(min(min(min(min(min(abs(dfUL),abs(dfUC)),abs(dfUR)),abs(dfCL)),abs(dfCR)),abs(dfDL)),abs(dfDC)),abs(dfDR));
% dfNeighRange = max(fNeighMax - fNeighMin, 1);







% 			dfUL = f0 - single(F0(rowU, colL, 1, c));
% 			dfUC = f0 - single(F0(rowU, colC, 1, c));
% 			dfUR = f0 - single(F0(rowU, colR, 1, c));
% 			dfCL = f0 - single(F0(rowC, colL, 1, c));
% 			dfCR = f0 - single(F0(rowC, colR, 1, c));
% 			dfDL = f0 - single(F0(rowD, colL, 1, c));
% 			dfDC = f0 - single(F0(rowD, colC, 1, c));
% 			dfDR = f0 - single(F0(rowD, colR, 1, c));















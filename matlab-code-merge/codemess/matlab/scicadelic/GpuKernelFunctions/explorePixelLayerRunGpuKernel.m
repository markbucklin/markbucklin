function [S, varargout] = explorePixelLayerRunGpuKernel(P, S0, pbMinDist, rowSubs, colSubs, frameSubs)
% MEASURE A GEODESIC DISTANCE TO NEAREST LAYER TRANSITION ( --> and/or label transition?!?!?)
%
% >> [peakDist, isPeak, isBorder] = explorePixelLayerRunGpuKernel(P, S0, rowSubs, colSubs, frameSubs)



% ============================================================
% PROCESS INPUT - FILL DEFAULTS
% ============================================================
[numRows, numCols, numFrames] = size(P);
if nargin < 2
	S0 = [];
	% 	S0 = gpuArray.zeros(numRows, numCols, 'single');
end
if nargin < 3
	pbMinDist = [];
end
if nargin < 4
	rowSubs = gpuArray.colon(1,numRows)';
	colSubs = gpuArray.colon(1,numCols);
	frameSubs = reshape(gpuArray.colon(1, numFrames), 1,1,numFrames);
end
if isempty(S0) % could also check nnz(S0)<1  -> initialize to pPx and call multiple times
	S0 = mean(P,3);
end
if isempty(pbMinDist)
	pbMinDist = single(2);
end



% ============================================================
% CALL SUB-FUNCTION USING GPU/ARRAYFUN (COMPILES CUDA KERNEL)
% ============================================================
[S, isLocalPeak, isLocalBorder] = arrayfun( @peakBorderDistKernel,...
	P, S0, rowSubs, colSubs, frameSubs);



% ============================================================
% MANAGE OUTPUT
% ============================================================
if nargout>1
	varargout{1} = isLocalPeak;
	if nargout>2
		varargout{2} = isLocalBorder;
	end
end












% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################
	function [sPxNew, isPxPeak, isPxBorder] = peakBorderDistKernel(pPx, sPx, rowC, colC, k)
		% Adds difference between current-pixel & neighbor with shortest path, to propagate/update shortest path to a zero-crossing
		% pPx -> pixelLayer(rowC,colC,n)
		% sPx -> borderDist(rowC,colC,n)
		
		if (sPx == 0)
			% INITIALIZATION
			sPxNew = pPx;
			isPxPeak = false;
			isPxBorder = false;
			
		else
			% CALCULATE SUBSCRIPTS FOR SURROUNDING-PIXELS
			rowU = max( 1, rowC-1);
			rowD = min( numRows, rowC+1);
			colL = max( 1, colC-1);
			colR = min( numCols, colC+1);
			
			% GET NEIGHBORHOOD (ADJACENT-PIXELS) LAYER PROBABILITY-VALUES
			pUL = P(rowU, colL, k);
			pUC = P(rowU, colC, k);
			pUR = P(rowU, colR, k);
			pCL = P(rowC, colL, k);
			pCR = P(rowC, colR, k);
			pDL = P(rowD, colL, k);
			pDC = P(rowD, colC, k);
			pDR = P(rowD, colR, k);
			
			% DETERMINE IF ANY LAYER-TRANSITION (ZERO-CROSSING) EXISTS BETWEEN PIXEL & NEIGHBORS
			pPxSign = sign(pPx);
			isPxBorder = (pPxSign ~= sign(pUL)) ...
				|| (pPxSign ~= sign(pUC)) ...
				|| (pPxSign ~= sign(pUR)) ...
				|| (pPxSign ~= sign(pCL)) ...
				|| (pPxSign ~= sign(pCR)) ...
				|| (pPxSign ~= sign(pDL)) ...
				|| (pPxSign ~= sign(pDC)) ...
				|| (pPxSign ~= sign(pDR)) ;
			
			if isPxBorder
				% IF BORDER PIXEL -> INITIALIZE TRANSITION-DISTANCE WITH PIXEL-LAYER-PROBABILITY VALUE
				sPxNew = pPx;
				isPxPeak = false;
				
			else
				% CAN ASSUME ALL PIXELS IN NEIGHBORHOOD ARE SAME LAYER & NON-BORDER
				
				% GET NEIGHBORHOOD (ADJACENT) PIXEL LAYER-TRANSITION-DISTANCES (K-1)
				sUL = S0(rowU, colL);
				sUC = S0(rowU, colC);
				sUR = S0(rowU, colR);
				sCL = S0(rowC, colL);
				sCR = S0(rowC, colR);
				sDL = S0(rowD, colL);
				sDC = S0(rowD, colC);
				sDR = S0(rowD, colR);
				
				% COMPUTE SHORTEST-PATH (GEODESIC) TO A ZERO-CROSSING ('LAYER-TRANSITION-DISTANCE')
				sGridMin = min(min(min(min(min(min(min(sUL,sUC),sUR),sDL),sDC),sDR),sCL),sCR);
				sGridMax = max(max(max(max(max(max(max(sUL,sUC),sUR),sDL),sDC),sDR),sCL),sCR);
				
				if (pPx > 0) % or... (sPx > 0)
					% FIND MIN DIST(K-1) FROM NEIGHBOR PIXELS: (BRIGHT/CELL-LAYER -> DIST FROM VESSEL)					
					sPxNew = sGridMin + pPx;
					sPeak = (max(sPxNew,sPx) >= sGridMax);
					
				else
					% FIND MAX DIST(K-1) FROM NEIGHBOR PIXELS: (DARK/VESSEL-LAYER -> DIST FROM CELL)					
					sPxNew = sGridMax + pPx;
					sPeak = (min(sPxNew,sPx) <= sGridMin);
					
				end
				
				isPxPeak = sPeak && (abs(sPxNew) >= pbMinDist);
				
			end
		end
		
	end


end






% % FIND SURROUNDING MAX -> COMPARE CURRENT PIXEL TO SURROUNDING MAX
% 					pSurrMax = max(max(max(max(max(max(max(pUL,pUC),pUR),pDL),pDC),pDR),pCL),pCR);
% 					pPeak = (pPx >= pSurrMax);
% % FIND SURROUNDING MIN -> COMPARE CURRENT PIXEL TO SURROUNDING MIN
% 					pSurrMin = min(min(min(min(min(min(min(pUL,pUC),pUR),pDL),pDC),pDR),pCL),pCR);
% 					pPeak = (pPx <= pSurrMin);
% isPxPeak = (pPeak && sPeak) && (abs(sPxNew) > pbMinDist);

% % FIND SURROUNDING MIN -> COMPARE CURRENT PIXEL TO SURROUNDING MIN
% 					pSurrMin = min(min(min(min(min(min(min(pUL,pUC),pUR),pDL),pDC),pDR),pCL),pCR);
% 					isPxPeak = (pPx <= pSurrMin) || (sPxNew <= sGridMin);
% % FIND SURROUNDING MAX -> COMPARE CURRENT PIXEL TO SURROUNDING MAX
% 					pSurrMax = max(max(max(max(max(max(max(pUL,pUC),pUR),pDL),pDC),pDR),pCL),pCR);					
% 					isPxPeak = (pPx >= pSurrMax) || (sPxNew >= sGridMax);
					
					
% 					isPxPeak = (sPx >= sBlockMax);
% 					isPxPeak = (sPx <= sBlockMin);

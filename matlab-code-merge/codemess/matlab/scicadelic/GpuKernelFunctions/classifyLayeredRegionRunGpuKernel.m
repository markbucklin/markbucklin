function [S, varargout] = classifyLayeredRegionRunGpuKernel(R, S0, minBorderDist2CallPeak, rowSubs, colSubs, frameSubs)
% MEASURE A GEODESIC DISTANCE TO NEAREST LAYER TRANSITION ( --> and/or label transition?!?!?)
%
% >> [borderDist, isPeak, isBorder] = explorePixelLayerRunGpuKernel(P, S0, rowSubs, colSubs, frameSubs)



% ============================================================
% PROCESS INPUT - FILL DEFAULTS
% ============================================================
[numRows, numCols, numFrames] = size(R);
if nargin < 2
	S0 = [];
	% 	S0 = gpuArray.zeros(numRows, numCols, 'single');
end
if nargin < 3
	minBorderDist2CallPeak = [];
end
if nargin < 4
	rowSubs = gpuArray.colon(1,numRows)';
	colSubs = gpuArray.colon(1,numCols);
	frameSubs = reshape(gpuArray.colon(1, numFrames), 1,1,numFrames);
end
if isempty(S0) % could also check nnz(S0)<1  -> initialize to pPx and call multiple times
	S0 = single( sign(mean(R,3))*numRows*numCols);
	% 	S0 = gpuArray.ones(numRows,numCols,'single') .* sign(mean(R,3))*numRows*numCols;
end
if isempty(minBorderDist2CallPeak)
	minBorderDist2CallPeak = gpuArray(single(1));
end



% ============================================================
% CALL SUB-FUNCTION USING GPU/ARRAYFUN (COMPILES CUDA KERNEL)
% ============================================================
[S, isLocalPeak, isLocalBorder] = arrayfun( @peakBorderDistKernel,...
	R, S0, rowSubs, colSubs, frameSubs);



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
	function [sPxNew, sPeakCnt, rBorderCnt] = peakBorderDistKernel(rPx, sPx, rowC, colC, k)
		% Adds difference between current-pixel & neighbor with shortest path, to propagate/update shortest path to a zero-crossing
		% rPx -> pixelLayer(rowC,colC,n)
		% sPx -> borderDist(rowC,colC,n)
		
		if (sPx == 0)
			% INITIALIZATION
			sPxNew = rPx;
			sPeakCnt = int32(0);
			rBorderCnt = int32(0);
			
		else
			% CALCULATE SUBSCRIPTS FOR SURROUNDING-PIXELS
			rowU = max( 1, rowC-1);
			rowD = min( numRows, rowC+1);
			colL = max( 1, colC-1);
			colR = min( numCols, colC+1);
			
			% GET NEIGHBORHOOD (ADJACENT-PIXELS) LAYER PROBABILITY-VALUES
			rUL = R(rowU, colL, k);
			rUC = R(rowU, colC, k);
			rUR = R(rowU, colR, k);
			rCL = R(rowC, colL, k);
			rCR = R(rowC, colR, k);
			rDL = R(rowD, colL, k);
			rDC = R(rowD, colC, k);
			rDR = R(rowD, colR, k);
			
			blockMaxRMag = max(max(max(max(max(max(max(...
					abs(rUL),abs(rUC)),abs(rUR)),abs(rDL)),abs(rDC)),abs(rDR)),abs(rCL)),abs(rCR));
			
			% DETERMINE IF ANY LAYER-TRANSITION (ZERO-CROSSING) EXISTS BETWEEN PIXEL & NEIGHBORS
			rPxSign = sign(rPx);
			isPxBorder = (rPxSign ~= sign(rUL)) ...
				|| (rPxSign ~= sign(rUC)) ...
				|| (rPxSign ~= sign(rUR)) ...
				|| (rPxSign ~= sign(rCL)) ...
				|| (rPxSign ~= sign(rCR)) ...
				|| (rPxSign ~= sign(rDL)) ...
				|| (rPxSign ~= sign(rDC)) ...
				|| (rPxSign ~= sign(rDR)) ;
			% 						dsPx = rPxSign - rPx;
			% 			dsPx = rPx;
			dsPx = rPx / blockMaxRMag;
			
			if isPxBorder
				% IF BORDER PIXEL -> INITIALIZE TRANSITION-DISTANCE WITH PIXEL-LAYER-PROBABILITY VALUE
				% 				sPxNew = rPx;
				sPxNew = dsPx;
				sPeakCnt = int32(0);
				rBorderCnt = int32(rPxSign);
				
			else
				% CAN ASSUME ALL PIXELS IN NEIGHBORHOOD ARE SAME LAYER & NON-BORDER
				rBorderCnt = int32(0);
				
				% GET NEIGHBORHOOD (ADJACENT) PIXEL LAYER-TRANSITION-DISTANCES (K-1)
				diagDist = single(realsqrt(2));
				sUL = S0(rowU, colL)+dsPx*diagDist;
				sUC = S0(rowU, colC)+dsPx;
				sUR = S0(rowU, colR)+dsPx*diagDist;
				sCL = S0(rowC, colL)+dsPx;
				sCR = S0(rowC, colR)+dsPx;
				sDL = S0(rowD, colL)+dsPx*diagDist;
				sDC = S0(rowD, colC)+dsPx;
				sDR = S0(rowD, colR)+dsPx*diagDist;
				
				% COMPUTE SHORTEST-PATH (GEODESIC) TO A ZERO-CROSSING ('LAYER-TRANSITION-DISTANCE')
				sPxSign = sign(sPx);
				sFixedMin = abs(sPx);
				sFixedMin = min(abs(sFixedMin), abs(sUL)*(sPxSign == sign(sUL)));
				sFixedMin = min(abs(sFixedMin), abs(sUC)*(sPxSign == sign(sUC)));
				sFixedMin = min(abs(sFixedMin), abs(sUR)*(sPxSign == sign(sUR)));
				sFixedMin = min(abs(sFixedMin), abs(sCL)*(sPxSign == sign(sCL)));
				sFixedMin = min(abs(sFixedMin), abs(sCR)*(sPxSign == sign(sCR)));
				sFixedMin = min(abs(sFixedMin), abs(sDL)*(sPxSign == sign(sDL)));
				sFixedMin = min(abs(sFixedMin), abs(sDC)*(sPxSign == sign(sDC)));
				sFixedMin = min(abs(sFixedMin), abs(sDR)*(sPxSign == sign(sDR)));
				sPxNew = sFixedMin*sPxSign;
				
				% TODO: KINDA WORKING
				% 				neighborFixedMin = min(min(min(min(min(min(min(...
				% 					abs(sUL),abs(sUC)),abs(sUR)),abs(sDL)),abs(sDC)),abs(sDR)),abs(sCL)),abs(sCR));
				neighborFixedMax = max(max(max(max(max(max(max(...
					abs(sUL),abs(sUC)),abs(sUR)),abs(sDL)),abs(sDC)),abs(sDR)),abs(sCL)),abs(sCR));
				sPxIsPeak = (sFixedMin < min(numRows,numCols)) ...
					&& ((abs(sPx)+abs(dsPx)*diagDist) >= (neighborFixedMax)) ...
					&& (sFixedMin >= minBorderDist2CallPeak);
				sPeakCnt = int32(sPxIsPeak) * int32(sign(sPxNew));
				% 				sPeakCnt = int32(sign(sPxNew)) * int32(sPxIsPeak && (abs(sPxNew) >= minBorderDist2CallPeak));
				
			end
		end
		
	end


end




% 				sGridMin = min(min(min(min(min(min(min(sUL,sUC),sUR),sDL),sDC),sDR),sCL),sCR);
% 				sGridMax = max(max(max(max(max(max(max(sUL,sUC),sUR),sDL),sDC),sDR),sCL),sCR);

% 				if (sFixedMin > 0)%(sPx > 0) % or... (rPx > 0)
% FIND MIN DIST(K-1) FROM NEIGHBOR PIXELS: (BRIGHT/CELL-LAYER -> DIST FROM VESSEL)
% 					sPxNew = sGridMin + rPx;
% 					sPxIsPeak = (max(sPxNew,sPx) >= sGridMax);
% 					sPxNew = min(sPx, sGridMin+dsPx); %sGridMin + rPx;
% 				else
% FIND MAX DIST(K-1) FROM NEIGHBOR PIXELS: (DARK/VESSEL-LAYER -> DIST FROM CELL)
% 					sPxNew = sGridMax + rPx;
% 					sPxIsPeak = (min(sPxNew,sPx) <= sGridMin);
% 					sPxNew = max(sPx, sGridMax-dsPx);
% 				end


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

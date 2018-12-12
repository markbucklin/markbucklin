function [S0, varargout] = updateLayerTransitionDistanceRunGpuKernel(P, S0, rowSubs, colSubs, frameSubs)
% MEASURE A GEODESIC DISTANCE TO NEAREST LAYER TRANSITION ( --> and/or label transition?!?!?)


[numRows, numCols, numFrames] = size(P);

if nargin < 2
	S0 = gpuArray.zeros(numRows, numCols, 'single');
end
if nargin < 3
	rowSubs = gpuArray.colon(1,numRows)';
	colSubs = gpuArray.colon(1,numCols);
	frameSubs = reshape(gpuArray.colon(1, numFrames), 1,1,numFrames);
end

[S, isLocalPeak, isLocalBorder] = arrayfun( @transitionDistKernel,...
	P, S0, rowSubs, colSubs, frameSubs);



if nargout>1
	varargout{1} = isLocalPeak;
	if nargout>2
		varargout{2} = isLocalBorder;
	end
end












% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################
	function [sPxNew, isPxPeak, isPxBorder] = transitionDistKernel(pPx, sPx, rowC, colC, n)
		% Adds difference between current-pixel & neighbor with shortest path, to propagate/update shortest path to a zero-crossing
		% rPx -> pixelLayer(rowC,colC,n)
		% sPx -> layerTransitionDist(rowC,colC,n)
		
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
			pUL = P(rowU, colL, n);
			pUC = P(rowU, colC, n);
			pUR = P(rowU, colR, n);
			pCL = P(rowC, colL, n);
			pCR = P(rowC, colR, n);
			pDL = P(rowD, colL, n);
			pDC = P(rowD, colC, n);
			pDR = P(rowD, colR, n);
			
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
				% CAN ASSUME ALL PIXELS IN NEIGHBORHOOD ARE SAME LAYER
				
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
				sBlockMin = min(min(min(min(min(min(min(...
					sUL,sUC),sUR),sDL),sDC),sDR),sCL),sCR);
				sBlockMax = max(max(max(max(max(max(max(...
					sUL,sUC),sUR),sDL),sDC),sDR),sCL),sCR);
				
				if (pPx > 0) % or... (sPx > 0)
					% FIND MIN DIST(K-1) FROM NEIGHBOR PIXELS: (BRIGHT/CELL-LAYER -> DIST FROM VESSEL)
					sPxNew = sBlockMin + pPx;
					isPxPeak = (sPx >= sBlockMax);
					
				else
					% FIND MAX DIST(K-1) FROM NEIGHBOR PIXELS: (DARK/VESSEL-LAYER -> DIST FROM CELL)
					sPxNew = sBlockMax + pPx;
					isPxPeak = (sPx <= sBlockMin);
					
				end
				
				
			end
		end
		
	end


end








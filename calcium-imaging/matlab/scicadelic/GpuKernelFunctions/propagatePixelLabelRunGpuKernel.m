function [pixelLabel, varargout] = propagatePixelLabelRunGpuKernel(pixelLabelInitial, pixelLayerUpdate,...
	seedingThreshold, joiningThreshold, maxRadius, rowSubs, colSubs, frameSubs)
% SAMPLE SURROUND TO COMPUTE/UPDATE LAYER-PROBABILITY




% ============================================================
% PROCESS INPUT - FILL DEFAULTS
% ============================================================
[numRows, numCols, numFrames] = size(pixelLayerUpdate);
if nargin < 6
	rowSubs = gpuArray.colon(1,numRows)';
	colSubs = gpuArray.colon(1,numCols);
	frameSubs = reshape(gpuArray.colon(1, numFrames), 1,1,numFrames);
	if nargin < 5
		maxRadius = [];
		if nargin < 4
			joiningThreshold = [];
			if nargin < 3
				seedingThreshold = [];				
			end
		end
	end
end
if isempty(seedingThreshold)
	seedingThreshold = single(.75);
end
if isempty(joiningThreshold)
	joiningThreshold = single(.25); % class-probability (i.e. P(px=cell))
end
if isempty(maxRadius)
	maxRadius = single(15);
end




% ============================================================
% CONSTRUCT/LAUNCH CUDA-KERNEL WITH CALL TO ARRAYFUN
% ============================================================
[pixelLabel, pixelLabelSteady] = arrayfun( @propagateLabelKernel,...
	pixelLabelInitial, pixelLayerUpdate, rowSubs, colSubs, frameSubs);


if nargout>1
	varargout{1} = pixelLabelSteady;
end






% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################
	function [ulPx, lPxSteady] = propagateLabelKernel(lPx, pPx, rowC, colC, n)
		
		
		if (pPx <= joiningThreshold) % (erf(pi*pPx)
			ulPx = uint32(0);
			
		else
			% CALCULATE SUBSCRIPTS FOR SURROUNDING-PIXELS TO SAMPLE
			rowU = max( 1, rowC-1);
			rowD = min( numRows, rowC+1);
			colL = max( 1, colC-1);
			colR = min( numCols, colC+1);
			
			% GET NEIGHBORHOOD (ADJACENT-PIXELS) LABEL PROBABILITY-VALUES
			pPxUL = pixelLayerUpdate(rowU, colL, n);
			pPxUC = pixelLayerUpdate(rowU, colC, n);
			pPxUR = pixelLayerUpdate(rowU, colR, n);
			pPxDL = pixelLayerUpdate(rowD, colL, n);
			pPxDC = pixelLayerUpdate(rowD, colC, n);
			pPxDR = pixelLayerUpdate(rowD, colR, n);
			pPxCL = pixelLayerUpdate(rowC, colL, n);
			pPxCR = pixelLayerUpdate(rowC, colR, n);
						
			% GET NEIGHBORHOOD (ADJACENT) PIXEL LABELS
			lPxUL = pixelLabelInitial(rowU, colL);
			lPxUC = pixelLabelInitial(rowU, colC);
			lPxUR = pixelLabelInitial(rowU, colR);
			lPxDL = pixelLabelInitial(rowD, colL);
			lPxDC = pixelLabelInitial(rowD, colC);
			lPxDR = pixelLabelInitial(rowD, colR);
			lPxCL = pixelLabelInitial(rowC, colL);
			lPxCR = pixelLabelInitial(rowC, colR);
			
			% FIND MAXIMUM P-VALUE
			maxP = max(max(max(max(max(max(max(max(...
				pPx,pPxUL),pPxUC),pPxUR),pPxDL),pPxDC),pPxDR),pPxCL),pPxCR);
			
			% REPLACE CURRENT-PIXEL LABEL WITH LABEL FROM NEIGHBORHOOD-PIXEL WITH GREATEST P-VALUE
			ulPx = uint32(0);
			bCC = (pPx  ==maxP);
			bUL = (pPxUL==maxP);
			bUC = (pPxUC==maxP);
			bUR = (pPxUR==maxP);
			bCR = (pPxCR==maxP);
			bDR = (pPxDR==maxP);
			bDC = (pPxDC==maxP);
			bDL = (pPxDL==maxP);
			bCL = (pPxCL==maxP);
			ulPx = ulPx + lPx*uint32(bCC & (ulPx==0));
			ulPx = ulPx + lPxUL*uint32(bUL & (ulPx==0));
			ulPx = ulPx + lPxUC*uint32(bUC & (ulPx==0));
			ulPx = ulPx + lPxUR*uint32(bUR & (ulPx==0));
			ulPx = ulPx + lPxCR*uint32(bCR & (ulPx==0));
			ulPx = ulPx + lPxDR*uint32(bDR & (ulPx==0));
			ulPx = ulPx + lPxDC*uint32(bDC & (ulPx==0));
			ulPx = ulPx + lPxDL*uint32(bDL & (ulPx==0));
			ulPx = ulPx + lPxCL*uint32(bCL & (ulPx==0));
					
			% IF LAYER-LIKELIHOOD SUGGESTS CELL-LAYER BUT RETRIEVED LABEL IS EMPTY -> REINITIALIZED LABEL
			if (ulPx == 0) && (pPx >= seedingThreshold)
				ulPx = bitor( uint32(rowC) , bitshift(uint32(colC), 16));
			end			
		end
		
		% MARK WHETHER UPDATED LABEL HAS CHANGED
		lPxSteady = (lPx == ulPx);
		
	end


end















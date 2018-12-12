function [bestLabel, varargout] = propagatePixelLabelRestrictedRunGpuKernel(Q, R, rMinSeed, rMinJoin, maxRadius, rowSubs, colSubs, frameSubs)
% SAMPLE SURROUND TO COMPUTE/UPDATE LAYER-PROBABILITY
% [bestLabel, varargout] = propagatePixelLabelRestrictedRunGpuKernel(pixelLabelInitial, pixelLayerUpdate,...
% 	seedingThreshold, joiningThreshold, maxRadius, rowSubs, colSubs, frameSubs)
% >> [bestLabel, bestProb, bestDist, pixelLabelSteady] = propagatePixelLabelRestrictedRunGpuKernel(Q, R)


% ============================================================
% PROCESS INPUT - FILL DEFAULTS
% ============================================================
[numRows, numCols, numFrames] = size(R);
numPixels = single(numRows*numCols);
if nargin < 6
	rowSubs = gpuArray.colon(1,numRows)';
	colSubs = gpuArray.colon(1,numCols);
	frameSubs = reshape(gpuArray.colon(1, numFrames), 1,1,numFrames);
	if nargin < 5
		maxRadius = [];
		if nargin < 4
			rMinJoin = [];
			if nargin < 3
				rMinSeed = [];
			end
		end
	end
end
if isempty(rMinSeed)
	rMinSeed = single(.75);
end
if isempty(rMinJoin)
	rMinJoin = single(.25); % class-probability (i.e. P(px=cell))
end
if isempty(maxRadius)
	maxRadius = single(12);
end


% ============================================================
% CONSTRUCT/LAUNCH CUDA-KERNEL WITH CALL TO ARRAYFUN
% ============================================================
[bestLabel, bestProb, bestDist, pixelLabelSteady] = arrayfun( @propagateLabelKernel, Q, R, rowSubs, colSubs, frameSubs);


if nargout>1
	varargout{1} = bestProb;
	if nargout>2
		varargout{2} = bestDist;
		if nargout>3
			varargout{3} = pixelLabelSteady;
		end
	end
end





% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################
	function [uqPx, upPx, usPx, qPxSteady] = propagateLabelKernel(qPx, rPx, rowC, colC, n)
		
		if (rPx <= rMinJoin) % (erf(pi*pPx)
			uqPx = uint32(0);
			upPx = rPx;
			usPx = single(numPixels);%single(uqPx);
			qPxSteady = false;
			
		else
			% CALCULATE SUBSCRIPTS FOR SURROUNDING-PIXELS TO SAMPLE
			rowU = max( 1, rowC-1);
			rowD = min( numRows, rowC+1);
			colL = max( 1, colC-1);
			colR = min( numCols, colC+1);
			
			% GET NEIGHBORHOOD (ADJACENT) PIXEL LABELS (Q)
			qUL = Q(rowU, colL);
			qUC = Q(rowU, colC);
			qUR = Q(rowU, colR);
			qCL = Q(rowC, colL);
			qCR = Q(rowC, colR);
			qDL = Q(rowD, colL);
			qDC = Q(rowD, colC);
			qDR = Q(rowD, colR);
			
			% GET NEIGHBORHOOD (ADJACENT-PIXELS) LABEL PROBABILITY-VALUES
			rUL = R(rowU, colL, n);
			rUC = R(rowU, colC, n);
			rUR = R(rowU, colR, n);
			rCL = R(rowC, colL, n);
			rCR = R(rowC, colR, n);
			rDL = R(rowD, colL, n);
			rDC = R(rowD, colC, n);
			rDR = R(rowD, colR, n);
			
			% GET NEIGHBORHOOD (ADJACENT) DISTANCES TO THEIR LABELS (S)
			sUL = labelDist(qUL,-1,-1);
			sUC = labelDist(qUC,-1, 0);
			sUR = labelDist(qUR,-1, 1);
			sCL = labelDist(qCL, 0,-1);
			sCR = labelDist(qCR, 0, 1);
			sDL = labelDist(qDL, 1,-1);
			sDC = labelDist(qDC, 1, 0);
			sDR = labelDist(qDR, 1, 1);
			
			% FIND MAXIMUM Pcell OF ALL SURROUNDING PIXELS
			rmax = max(max(max(max(max(max(max(max(...
				rPx,rUL),rUC),rUR),rDL),rDC),rDR),rCL),rCR);
			rsum = rPx + rUL + rUC + rUR + rDL + rDC + rDR + rCL + rCR;
			rmean = rsum / 9;
			
			% REPLACE CURRENT-PIXEL LABEL WITH LABEL FROM NEIGHBORHOOD-PIXEL WITH GREATEST P-VALUE
			uqPx = qPx;
			upPx = rPx;
			usPx = labelDist(qPx,0,0);
			[uqPx, upPx, usPx] = takeBetterLabel( qUL, rUL, sUL);
			[uqPx, upPx, usPx] = takeBetterLabel( qUC, rUC, sUC);
			[uqPx, upPx, usPx] = takeBetterLabel( qUR, rUR, sUR);
			[uqPx, upPx, usPx] = takeBetterLabel( qCL, rCL, sCL);
			[uqPx, upPx, usPx] = takeBetterLabel( qCR, rCR, sCR);
			[uqPx, upPx, usPx] = takeBetterLabel( qDC, rDC, sDC);
			[uqPx, upPx, usPx] = takeBetterLabel( qDL, rDL, sDL);
			[uqPx, upPx, usPx] = takeBetterLabel( qDR, rDR, sDR);
			
			
			% IF LAYER-LIKELIHOOD SUGGESTS CELL-LAYER BUT RETRIEVED LABEL IS EMPTY -> REINITIALIZED LABEL
			% 			if (uqPx == 0) && (rPx >= rMinSeed)
			% 				uqPx = bitor( uint32(rowC) , bitshift(uint32(colC), 16));
			% 			end
			
			% MARK WHETHER UPDATED LABEL HAS CHANGED
			qPxSteady = (qPx == uqPx);
			
		end
		
		
		
		function [qo, po, ro] = takeBetterLabel(q, p, r)
			labelValid = (q ~= 0);
			% 			labelSame = (q == uqPx);
			% 			labelCloser = (r < usPx);
			distValid = (r < maxRadius);
			probGood = (p >= rmean);
			probBetter = (p > upPx);
			% 			probBest = (p == rmax);
			qo = uqPx;
			po = upPx;
			ro = usPx;
			if labelValid && probGood && distValid
				qo = q;
				po = p;
				ro = r;
				
				% 				if labelValid && probBetter && distValid
				% 					if labelValid && probBest && distValid
				% 				if probBetter && labelCloser
				%
				% 				else
				%
				% 				end
			end
			
		end
		function s = labelDist(q,i,j)
			% Calculates distance to label held by given pixel, returning numCols+numFrames if pixel has no label
			qnz = single(q~=0);
			dy = single(rowC+i) - single(bitand( q, uint32(65535)));
			dx = single(colC+j) - single(bitand( bitshift(q, -16), uint32(65535)));
			s = qnz*realsqrt( realpow(dx,2) + realpow(dy,2) ) - (qnz-1)*numPixels;
			
		end
		% 		function s = takeLabelIfTrue(condition, sIf, sNot)
		% 			c = uint32(condition);
		% 			s = sIf*c - sNot*(c-1);
		% 		end
		% 		function p = takePCellIfTrueAndGreater(condition, pIf, pElse)
		% 			c = uint32(condition);
		% 			p = pIf*c + pElse*(c-1);
		% 	end
	end


end










% 			ulPx = uint32(0);
% 			upPx = pPx;
% 			ulPx = takeLabelIfTrue( (pCL>upPx) & (labelDist(lCL)<=maxRadius), lCL, ulPx);
% 			upPx = takePCellIfTrueAndGreater( (pCL==upPx), pCL, upPx);

% 			ulPx = takeLabelIfTrue( (pUL>upPx) & (labelDist(lCL)<=maxRadius), lCL, ulPx);
% 			ulPx = takeLabelIfTrue( (pCR>upPx) & (labelDist(lCR)<=maxRadius), lCR, ulPx);
% 			ulPx = takeLabelIfTrue( (pUC>upPx) & (labelDist(lUC)<=maxRadius), lUC, ulPx);
% 			ulPx = takeLabelIfTrue( (pDC>upPx) & (labelDist(lDC)<=maxRadius), lDC, ulPx);
% 			ulPx = takeLabelIfTrue( (pCL>upPx) & (labelDist(lUL)<=maxRadius), lUL, ulPx);
% 			ulPx = takeLabelIfTrue( (pUR>upPx) & (labelDist(lUR)<=maxRadius), lUR, ulPx);
% 			ulPx = takeLabelIfTrue( (pDL>upPx) & (labelDist(lDL)<=maxRadius), lDL, ulPx);
% 			ulPx = takeLabelIfTrue( (pDR>upPx) & (labelDist(lDR)<=maxRadius), lDR, ulPx);
%TODO: need to add another check in here to make sure we're getting a good label??

% 			bCC = (pPx  ==maxP);
% 			bUL = (pUL==maxP);
% 			bUC = (pUC==maxP);
% 			bUR = (pUR==maxP);
% 			bCR = (pCR==maxP);
% 			bDR = (pDR==maxP);
% 			bDC = (pDC==maxP);
% 			bDL = (pDL==maxP);
% 			bCL = (pCL==maxP);
% 			ulPx = ulPx + lPx*uint32(bCC & (ulPx==0));
% 			ulPx = ulPx + lUL*uint32(bUL & (ulPx==0));
% 			ulPx = ulPx + lUC*uint32(bUC & (ulPx==0));
% 			ulPx = ulPx + lUR*uint32(bUR & (ulPx==0));
% 			ulPx = ulPx + lCR*uint32(bCR & (ulPx==0));
% 			ulPx = ulPx + lDR*uint32(bDR & (ulPx==0));
% 			ulPx = ulPx + lDC*uint32(bDC & (ulPx==0));
% 			ulPx = ulPx + lDL*uint32(bDL & (ulPx==0));
% 			ulPx = ulPx + lCL*uint32(bCL & (ulPx==0));
%
% 			ulPx = ulPx + lUL*uint32((pUL>pPx) & (ulPx==0));
% 			ulPx = ulPx + lUC*uint32((pUC>pPx) & (ulPx==0));
% 			ulPx = ulPx + lUR*uint32((pUR>pPx) & (ulPx==0));
% 			ulPx = ulPx + lCR*uint32((pCR>pPx) & (ulPx==0));
% 			ulPx = ulPx + lDR*uint32((pDR>pPx) & (ulPx==0));
% 			ulPx = ulPx + lDC*uint32((pDC>pPx) & (ulPx==0));
% 			ulPx = ulPx + lDL*uint32((pDL>pPx) & (ulPx==0));
% 			ulPx = ulPx + lCL*uint32((pCL>pPx) & (ulPx==0));

% ENSURE NEW LABEL (ASSUMED PEAK) IS NOT GREATER THAN SPECIFIED MAX RADIUS
% 			ulPx = ulPx*uint32(dr<=maxRadius);





% dy = single(rowC) - single(bitand( ulPx , uint32(65535)));
% dx = single(colC) - single(bitand( bitshift(ulPx, -16), uint32(65535)));
% dr = sqrt( dx^2 + dy^2 );
% ulPx = ulPx*uint32(dr<=maxRadius);
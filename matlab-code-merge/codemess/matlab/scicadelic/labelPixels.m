function [pixelLabel, pixelLayer, labelAccumStats, labelSize, pixelLabelLocked, labelIncidence, pixelLabelSteady] ...
	= labelPixels(F, pixelLabel, pixelLayer, pixelLabelLocked, labelIncidence, radiusRange, numRegionalSamples, bThresh)
% labelPixels

% ============================================================
% GET DIMENSIONS OF INPUT INTENSITY IMAGE(s) - F
% ============================================================
% persistent Lcnt
[numRows, numCols, numFrames] = size(F);
numPixels = numRows*numCols;


% ============================================================
% FILL MISSING INPUTS WITH DEFAULTS
% ============================================================
if nargin < 2
	pixelLabel = [];
end
if nargin < 3
	pixelLayer = [];
end
if nargin < 4
	pixelLabelLocked = gpuArray.zeros(numRows,numCols,'uint32');
end
if nargin < 5
	labelIncidence = [];
end
if (nargin < 6) || isempty(radiusRange)
	% 	radiusRange = 10;
	radiusRange = [8 24];
end
if (nargin < 7) || isempty(numRegionalSamples)
	numRegionalSamples = 4;
end
if (nargin < 8) || isempty(bThresh)
	bThresh = fix(min(range(F,1),[],2) / 4);
end
if isempty(pixelLabel)
	numPastLabels = uint32(0);
else
	numPastLabels = size(pixelLabel,3);
end
if isempty(labelIncidence)
	labelIncidence = gpuArray.zeros(numPixels,1,'uint16');
end
minPersistentSize = 32;
fgDiminishCoefficient = gpuArray(single(.5)); % was .9
labelLockMinCount = gpuArray(uint16(255));
fgMinProbability = gpuArray(single(.75));

% ============================================================
% PIXEL SUBSCRIPTS INTO STACK OF FRAMES
% ============================================================
rowSubs = gpuArray.colon(1,numRows)';
colSubs = gpuArray.colon(1,numCols);
frameSubs = reshape(gpuArray.colon(1, numFrames), 1,1,numFrames);




% ============================================================
% INIT/UPDATE LAYER-PROBABILITY MATRIX -> P,U (11.87)
% ============================================================
maxNumSamples = radiusRange(end)-radiusRange(1)+1;
if (maxNumSamples) > numRegionalSamples
	radiusSample = uint16(reshape(linspace(radiusRange(1), radiusRange(end), numRegionalSamples), 1,1,1,numRegionalSamples));
	actualNumSamples = numRegionalSamples;
else
	radiusSample = uint16(reshape(radiusRange(1):radiusRange(end), 1,1,1,maxNumSamples));
	actualNumSamples = maxNumSamples;
end
pixelLayerUpdate = sum(...
	arrayfun( @updatePixelLayerLikelihood,...
	F, rowSubs, colSubs, frameSubs, bThresh, radiusSample),...
	4) ./ actualNumSamples;

if ~isempty(pixelLayer)
	pixelLayerUpdate = bsxfun(@plus, pixelLayer, pixelLayerUpdate)./2;
	Psign = sign(pixelLayerUpdate);
	pixelLayerUpdate = bsxfun(@max, abs(pixelLayer)*fgDiminishCoefficient, abs(pixelLayerUpdate)) .* single(Psign);%TODO: find good coefficient
end
% countThresh = actualNumSamples * 7;%(numFrames-1);
% 	Pn = repmat(single(sum(Pnew>countThresh, 3) - sum(Pnew<0, 3))./numFrames, 1, 1, numFrames);
% else



% ============================================================
% INITIALIZE LABEL-MATRIX -> L (0.64)
% ============================================================
if isempty(pixelLabel)
	[Lcol, Lrow] = meshgrid(1:numCols, 1:numRows);
	LrcmixBO = bitor(uint32(Lrow(:)) , bitshift(uint32(Lcol(:)), 16, 'uint32'));
	pixelLabelInitial = reshape(gpuArray(LrcmixBO), numRows, numCols);
	% 	L = repmat( reshape(gpuArray(LrcmixBO), numRows, numCols), 1, 1, numFrames);
	% elseif ~ismatrix(L)
	% 	L = repmat(L, 1, 1, numFrames);
else
	[pixelLabelInitial, pixelLabelLocked] = arrayfun( @initializePixelLabel, pixelLabelLocked, max(pixelLayerUpdate,[],3), rowSubs, colSubs);
	% 	L = arrayfun( @initializePixelLabel, Pnew, rowSubs, colSubs);
	% do a L=Ln(:,:,end); mask=L>0; L = L.*mask + L(:,:,k).*(~mask);
end


% ============================================================
% PROPAGATE/SPREAD STRONGEST PIXEL LABELS -> L (2.67)
% ============================================================
[pixelLabel, pixelLabelSteady] = arrayfun( @propagatePixelLabel,...
	pixelLabelInitial, pixelLayerUpdate, rowSubs, colSubs, frameSubs);

% ============================================================
% ACCUMULATE LABEL VALUES -> COUNT, MIN, MAX, & MEAN (19.04)
% ============================================================
[labelAccumStats, labelSize] = getEncodedLabelSizeMeanMaxMin(pixelLabel, F); % 5X longer than any other line


% ============================================================
% ACCUMULATE LABEL COUNTS & FG/BG PROBABILITY
% ============================================================
labelIncidence = labelIncidence + uint16(sum(labelSize>minPersistentSize,2));
pixelLayer = sum(pixelLayerUpdate,3)/numFrames;















% ##################################################
% SUB-FUNCTIONS
% ##################################################

% ============================================================
% SAMPLE SURROUND TO COMPUTE/UPDATE LAYER-PROBABILITY
% ============================================================
	function upPx = updatePixelLayerLikelihood(fPx, rowC, colC, n, b, r)
		
		fPx_fp = single(fPx);
		
		% CALCULATE SUBSCRIPTS FOR SURROUNDING-PIXELS TO SAMPLE
		rowU = max( 1, rowC-r);
		rowD = min( numRows, rowC+r);
		colL = max( 1, colC-r);
		colR = min( numCols, colC+r);
		
		% RETRIEVE NON-LOCAL (REGIONAL) SAMPLES
		fPxUL = single(F(rowU, colL, n));
		fPxUC = single(F(rowU, colC, n));
		fPxUR = single(F(rowU, colR, n));
		fPxDL = single(F(rowD, colL, n));
		fPxDC = single(F(rowD, colC, n));
		fPxDR = single(F(rowD, colR, n));
		fPxCL = single(F(rowC, colL, n));
		fPxCR = single(F(rowC, colR, n));
		
		% COMPUTE DIFFERENCE BETWEEN CURRENT PIXEL & NON-LOCAL/REGIONAL SAMPLES
		regPxUL = fPx_fp - fPxUL;
		regPxUC = fPx_fp - fPxUC;
		regPxUR = fPx_fp - fPxUR;
		regPxDL = fPx_fp - fPxDL;
		regPxDC = fPx_fp - fPxDC;
		regPxDR = fPx_fp - fPxDR;
		regPxCL = fPx_fp - fPxCL;
		regPxCR = fPx_fp - fPxCR;
		
		% FIND MAXIMUM & MINIMUM INTENSITY VALUES FROM REGIONAL SAMPLE
		maxF = max(max(max(max(max(max(max(max(...
			fPx_fp,fPxUL),fPxUC),fPxUR),fPxDL),fPxDC),fPxDR),fPxCL),fPxCR);
		minF = min(min(min(min(min(min(min(min(...
			fPx_fp,fPxUL),fPxUC),fPxUR),fPxDL),fPxDC),fPxDR),fPxCL),fPxCR);
		rangeF = max(maxF - minF, 1);
		dMaxF = 1 - (maxF - fPx_fp)/rangeF;
		dMinF = 1 - (fPx_fp - minF)/rangeF;
		
		
		% COUNT NUMBER & POLARITY OF SIGNIFICANT PIXEL INTENSITY DIFFERENCES
		upPx = single(...
			sign(regPxUL) * single(abs(regPxUL)>b) ...
			+ sign(regPxUC) * single(abs(regPxUC)>b) ...
			+ sign(regPxUR) * single(abs(regPxUR)>b) ...
			+ sign(regPxCL) * single(abs(regPxCL)>b) ...
			+ sign(regPxCR) * single(abs(regPxCR)>b) ...
			+ sign(regPxDL) * single(abs(regPxDL)>b) ...
			+ sign(regPxDC) * single(abs(regPxDC)>b) ...
			+ sign(regPxDR) * single(abs(regPxDR)>b) );
		
		% COMBINE INTENSITY-DIFFERENCE INFORMATION WITH COUNT-BASED PREDICTOR
		upPx = upPx*(dMaxF*single(upPx>0)) + upPx*(dMinF*single(upPx<0));
		upPx = upPx / 8;
		
	end


% ============================================================
% SEARCH BACKWARDS THROUGH 3D-LABEL-ARRAY INPUT
% ============================================================
	function [lPx, lPxLocked] = initializePixelLabel(lPxLocked, pPx, rowC, colC)
		
		lPx = lPxLocked;
		if (pPx > 0) && (lPx <= 0)
			k = numPastLabels;
			lPx = pixelLabel(rowC,colC,k);
			while (lPx <= 0) && (k > 1)
				k = k-1;
				lPx = pixelLabel(rowC,colC,k);
			end
			if (lPx > 0)
				lPxRow = bitand( lPx , uint32(65535));
				lPxCol = bitand( bitshift(lPx, -16), uint32(65535));
				lPxIdx = lPxRow + numRows*(lPxCol-1);
				if (labelIncidence(lPxIdx) > labelLockMinCount)
					lPxLocked = lPx;
				end
			end
		end
		
	end



% ============================================================
% LABEL-PROBABILITY ESTIMATION & PROPAGATION
% ============================================================
	function [ulPx, lPxSteady] = propagatePixelLabel(lPx, pPx, rowC, colC, n)
		
		if (pPx <= fgMinProbability)
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
			
			% FIND MAXIMUM P-VALUE
			maxP = max(max(max(max(max(max(max(max(...
				pPx,pPxUL),pPxUC),pPxUR),pPxDL),pPxDC),pPxDR),pPxCL),pPxCR);
						
			% GET NEIGHBORHOOD (ADJACENT) PIXEL LABELS
			lPxUL = pixelLabelInitial(rowU, colL);
			lPxUC = pixelLabelInitial(rowU, colC);
			lPxUR = pixelLabelInitial(rowU, colR);
			lPxDL = pixelLabelInitial(rowD, colL);
			lPxDC = pixelLabelInitial(rowD, colC);
			lPxDR = pixelLabelInitial(rowD, colR);
			lPxCL = pixelLabelInitial(rowC, colL);
			lPxCR = pixelLabelInitial(rowC, colR);
			
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
			if (ulPx == 0)
				ulPx = bitor( uint32(rowC) , bitshift(uint32(colC), 16));
			end			
		end
		
		% MARK WHETHER UPDATED LABEL HAS CHANGED
		lPxSteady = (lPx == ulPx);
		
	end


% ============================================================
% LABEL-REFINEMENT
% ============================================================
	function newL = refinePixelLabel(lPx, pPx, rowC, colC, n)
		
		if (pPx <= fgMinProbability)
			newL = uint32(0);
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
			
			% FIND MAXIMUM P-VALUE
			maxP = max(max(max(max(max(max(max(max(...
				pPx,pPxUL),pPxUC),pPxUR),pPxDL),pPxDC),pPxDR),pPxCL),pPxCR);
			
			
			if (2*pPx < maxP)
				
				% IF PROBABILITY-VALUE IS RAPIDLY FALLING OFF AT CURRENT PIXEL
				newL = uint32(0);
				
			else
				% GET NEIGHBORHOOD (ADJACENT) PIXEL LABELS
				lPxUL = pixelLabel(rowU, colL, n);
				lPxUC = pixelLabel(rowU, colC, n);
				lPxUR = pixelLabel(rowU, colR, n);
				lPxDL = pixelLabel(rowD, colL, n);
				lPxDC = pixelLabel(rowD, colC, n);
				lPxDR = pixelLabel(rowD, colR, n);
				lPxCL = pixelLabel(rowC, colL, n);
				lPxCR = pixelLabel(rowC, colR, n);
				
				
				% REPLACE CURRENT-PIXEL LABEL WITH LABEL FROM NEIGHBORHOOD-PIXEL WITH GREATEST P-VALUE
				newL = uint32(0);
				bCC = (pPx  ==maxP);
				bUL = (pPxUL==maxP);
				bUC = (pPxUC==maxP);
				bUR = (pPxUR==maxP);
				bCR = (pPxCR==maxP);
				bDR = (pPxDR==maxP);
				bDC = (pPxDC==maxP);
				bDL = (pPxDL==maxP);
				bCL = (pPxCL==maxP);
				newL = newL + lPx*uint32(bCC & (newL==0));
				newL = newL + lPxUL*uint32(bUL & (newL==0));
				newL = newL + lPxUC*uint32(bUC & (newL==0));
				newL = newL + lPxUR*uint32(bUR & (newL==0));
				newL = newL + lPxCR*uint32(bCR & (newL==0));
				newL = newL + lPxDR*uint32(bDR & (newL==0));
				newL = newL + lPxDC*uint32(bDC & (newL==0));
				newL = newL + lPxDL*uint32(bDL & (newL==0));
				newL = newL + lPxCL*uint32(bCL & (newL==0));
				
				% IF P-VALUE TESTS PASSED BUT RETRIEVED LABEL IS EMPTY -> REINITIALIZED LABEL
				if (newL == 0)
					newL = bitor( uint32(rowC) , bitshift(uint32(colC), 16));
				end
			end
		end
		
	end


% ============================================================
% ACCUMULATE & ENCODE MAX, MIN, MEAN, & SIZE FOR EACH LABEL
% ============================================================
	function [encL, szL] = getEncodedLabelSizeMeanMaxMin(Lmat, Fmat)
		Lnz = logical(Lmat);
		% Lidx = find(Lnz);
		Lframe = bsxfun(@times, uint16(Lnz), frameSubs);
		LmatRow = bitand( Lmat , uint32(65535));
		LmatCol = bitand( bitshift(Lmat, -16), uint32(65535));
		LmatIdx = LmatRow(:) + numRows*(LmatCol(:)-1);
		Lsz = accumarray([LmatIdx(Lnz) , Lframe(Lnz)],...
			1, [numPixels, numFrames], @sum, 0, false);
		Lsum = accumarray([LmatIdx(Lnz) , Lframe(Lnz)],...
			single(Fmat(Lnz)), [numPixels, numFrames], @sum, single(0), false);
		Lmax = accumarray([LmatIdx(Lnz) , Lframe(Lnz)],...
			single(Fmat(Lnz)), [numPixels, numFrames], @max, single(0), false);
		Lmin = accumarray([LmatIdx(Lnz) , Lframe(Lnz)],...
			single(Fmat(Lnz)), [numPixels, numFrames], @min, single(0), false);
		
		% 		Lsz = accumarray([LmatRow(Lnz), LmatCol(Lnz), Lframe(Lnz)],...
		% 			1, [numRows, numCols, numFrames], @sum, 0, false);
		% 		Lsum = accumarray([LmatRow(Lnz), LmatCol(Lnz), Lframe(Lnz)],...
		% 			single(Fmat(Lnz)), [numRows, numCols, numFrames], @sum, single(0), false);
		% 		Lmax = accumarray([LmatRow(Lnz), LmatCol(Lnz), Lframe(Lnz)],...
		% 			single(Fmat(Lnz)), [numRows, numCols, numFrames], @max, single(0), false);
		% 		Lmin = accumarray([LmatRow(Lnz), LmatCol(Lnz), Lframe(Lnz)],...
		% 			single(Fmat(Lnz)), [numRows, numCols, numFrames], @min, single(0), false);
		
		% 		Lsnz = (Lsz>2) & (LmatRow>=1) & (LmatCol>=1);
		Lsnz = (Lsum>0);% & (LmatRow>=1) & (LmatCol>=1);
		%
		% 		Lmix = [uint16(Lsz(Lsnz)) , uint16(Lsum(Lsnz)./Lsz(Lsnz)) , uint16(Lmax(Lsnz)) , uint16(Lmin(Lsnz)) ]';
		% 		LmixTC = typecast(Lmix(:), 'double');
		%
		% 		encL = accumarray([LmatRow(Lsnz)+(numRows*(LmatCol(Lsnz)-1)) , Lframe(Lsnz)],...
		% 			LmixTC, [numPixels , numFrames], [],  0, true);
		
		[lsRow, lsCol] = find(Lsnz);
		Lmix = [uint16(Lsz(Lsnz)) , uint16(Lsum(Lsnz)./Lsz(Lsnz)) , uint16(Lmax(Lsnz)) , uint16(Lmin(Lsnz)) ]';
		LmixTC = typecast(Lmix(:), 'double');
		encL = accumarray([lsRow, lsCol], LmixTC, [numPixels, numFrames], [],  0, true);
		szL = uint16(Lsz);
	end





end











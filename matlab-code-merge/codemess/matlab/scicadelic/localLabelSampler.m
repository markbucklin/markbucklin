function [L, P, Lenc, Lsize, lockedLabel, Lcnt] = localLabelSampler(F, L, P, lockedLabel, Lcnt, radiusRange, numRegionalSamples, bThresh)
% Fast local contrast enhancement
% Samples pixels at distance estimated to be greater than 1 radius of the largest object (cell).
% Marks pixels as belonging to one of:
%			{
%			bright-foreground (cells)
%			dark-foreground (vessels)
%			background (neuropil)
%			}
%
%	INPUT:
%		F - [m,n] fluorescence intensity image, or [m,n,k] image stack -> gpuArray (underlying class: uint16)
%		sampleRadius - minumum distance in pixels that other pixels are sampled from for comparison
%		bThresh - minimum intensity difference between each pixel and sampled surround for difference to be considered significant and counted



% ==================================================
% GET DIMENSIONS OF INPUT INTENSITY IMAGE(s) - F
% ==================================================
% persistent Lcnt
[numRows, numCols, numFrames] = size(F);
numPixels = numRows*numCols;


% ==================================================
% FILL MISSING INPUTS WITH DEFAULTS
% ==================================================
if nargin < 2
	L = [];
end
if nargin < 3
	P = [];
end
if nargin < 4
	lockedLabel = gpuArray.zeros(numRows,numCols,'uint32');
end
if nargin < 5
	Lcnt = [];
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
if isempty(L)
	numPastLabels = uint32(0);
else
	numPastLabels = size(L,3);
end
if isempty(Lcnt)
	Lcnt = gpuArray.zeros(numPixels,1,'uint16');
end
minPersistentSize = 32;
fgDiminishCoefficient = gpuArray(single(.5)); % was .9
labelLockMinCount = gpuArray(uint16(255));
foregroundMinProbability = gpuArray(single(.75));

% ==================================================
% PIXEL SUBSCRIPTS INTO STACK OF FRAMES
% ==================================================
rowSubs = gpuArray.colon(1,numRows)';
colSubs = gpuArray.colon(1,numCols);
frameSubs = reshape(gpuArray.colon(1, numFrames), 1,1,numFrames);


	

% ==================================================
% INIT/UPDATE LAYER-PROBABILITY MATRIX -> P,U
% ==================================================
maxNumSamples = radiusRange(end)-radiusRange(1)+1;
if (maxNumSamples) > numRegionalSamples
	radiusSample = uint16(reshape(linspace(radiusRange(1), radiusRange(end), numRegionalSamples), 1,1,1,numRegionalSamples));
	actualNumSamples = numRegionalSamples;
else
	radiusSample = uint16(reshape(radiusRange(1):radiusRange(end), 1,1,1,maxNumSamples));
	actualNumSamples = maxNumSamples;
end
Pnew = sum(...
	arrayfun( @updatePixelLayerLikelihood,...
	F, rowSubs, colSubs, frameSubs, bThresh, radiusSample),...
	4) ./ actualNumSamples;

if ~isempty(P)
	Pnew = bsxfun(@plus, P, Pnew)./2;
	Psign = sign(Pnew);
	Pnew = bsxfun(@max, abs(P)*fgDiminishCoefficient, abs(Pnew)) .* single(Psign);%TODO: find good coefficient
end
% countThresh = actualNumSamples * 7;%(numFrames-1);
% 	Pn = repmat(single(sum(Pnew>countThresh, 3) - sum(Pnew<0, 3))./numFrames, 1, 1, numFrames);
% else



% ==================================================
% INITIALIZE LABEL-MATRIX -> L
% ==================================================
if isempty(L)
	[Lcol, Lrow] = meshgrid(1:numCols, 1:numRows);
	LrcmixBO = bitor(uint32(Lrow(:)) , bitshift(uint32(Lcol(:)), 16, 'uint32'));
	Linit = reshape(gpuArray(LrcmixBO), numRows, numCols);
	% 	L = repmat( reshape(gpuArray(LrcmixBO), numRows, numCols), 1, 1, numFrames);
	% elseif ~ismatrix(L)
	% 	L = repmat(L, 1, 1, numFrames);
else
	[Linit, lockedLabel] = arrayfun( @initializePixelLabel, lockedLabel, max(Pnew,[],3), rowSubs, colSubs);
	% 	L = arrayfun( @initializePixelLabel, Pnew, rowSubs, colSubs);
	% do a L=Ln(:,:,end); mask=L>0; L = L.*mask + L(:,:,k).*(~mask);
end


% ==================================================
% PROPAGATE/SPREAD STRONGEST PIXEL LABELS -> L
% ==================================================
L = arrayfun( @propagatePixelLabel,...
	Linit, Pnew, rowSubs, colSubs, frameSubs);

% ==================================================
% ACCUMULATE LABEL VALUES -> COUNT, MIN, MAX, & MEAN
% ==================================================
[Lenc, Lsize] = getEncodedLabelSizeMeanMaxMin(L, F);


% ==================================================
% ACCUMULATE LABEL COUNTS & FG/BG PROBABILITY
% ==================================================
Lcnt = Lcnt + uint16(sum(Lsize>minPersistentSize,2));
P = sum(Pnew,3)/numFrames;















% ##################################################
% SUB-FUNCTIONS
% ##################################################
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


% ##################################################
% STENCIL-OP SUB-FUNCTIONS -> RUNS ON GPU
% ##################################################
% ==================================================
% SAMPLE SURROUND TO COMPUTE/UPDATE LAYER-PROBABILITY
% ==================================================
	function uPx = updatePixelLayerLikelihood(fPx, rowC, colC, n, b, r)
		
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
		uPx = single(...
			sign(regPxUL) * single(abs(regPxUL)>b) ...
			+ sign(regPxUC) * single(abs(regPxUC)>b) ...
			+ sign(regPxUR) * single(abs(regPxUR)>b) ...
			+ sign(regPxCL) * single(abs(regPxCL)>b) ...
			+ sign(regPxCR) * single(abs(regPxCR)>b) ...
			+ sign(regPxDL) * single(abs(regPxDL)>b) ...
			+ sign(regPxDC) * single(abs(regPxDC)>b) ...
			+ sign(regPxDR) * single(abs(regPxDR)>b) );
		
		% COMBINE INTENSITY-DIFFERENCE INFORMATION WITH COUNT-BASED PREDICTOR
		uPx = uPx*(dMaxF*single(uPx>0)) + uPx*(dMinF*single(uPx<0));
		uPx = uPx / 8;
		
	end


% ==================================================
% SEARCH BACKWARDS THROUGH 3D-LABEL-ARRAY INPUT
% ==================================================
	function [lPx, lPxLocked] = initializePixelLabel(lPxLocked, pPx, rowC, colC)
		
		lPx = lPxLocked;
		if (pPx > 0) && (lPx <= 0)
			k = numPastLabels;
			lPx = L(rowC,colC,k);
			while (lPx <= 0) && (k > 1)
				k = k-1;
				lPx = L(rowC,colC,k);
			end
			if (lPx > 0)
				lPxRow = bitand( lPx , uint32(65535));
				lPxCol = bitand( bitshift(lPx, -16), uint32(65535));
				lPxIdx = lPxRow + numRows*(lPxCol-1);
				if (Lcnt(lPxIdx) > labelLockMinCount)
					lPxLocked = lPx;				
				end
			end
			% 		else
			% 			lPx = uint32(0);
		end
				
	end



% ==================================================
% LABEL-PROBABILITY ESTIMATION & PROPAGATION
% ==================================================
	function newL = propagatePixelLabel(lPx, pPx, rowC, colC, n)
		
		if (pPx <= foregroundMinProbability)
			newL = uint32(0);
		else
			
			% CALCULATE SUBSCRIPTS FOR SURROUNDING-PIXELS TO SAMPLE
			rowU = max( 1, rowC-1);
			rowD = min( numRows, rowC+1);
			colL = max( 1, colC-1);
			colR = min( numCols, colC+1);
			
			% GET NEIGHBORHOOD (ADJACENT-PIXELS) LABEL PROBABILITY-VALUES
			pPxUL = Pnew(rowU, colL, n);
			pPxUC = Pnew(rowU, colC, n);
			pPxUR = Pnew(rowU, colR, n);
			pPxDL = Pnew(rowD, colL, n);
			pPxDC = Pnew(rowD, colC, n);
			pPxDR = Pnew(rowD, colR, n);
			pPxCL = Pnew(rowC, colL, n);
			pPxCR = Pnew(rowC, colR, n);
			
			% FIND MAXIMUM P-VALUE
			maxP = max(max(max(max(max(max(max(max(...
				pPx,pPxUL),pPxUC),pPxUR),pPxDL),pPxDC),pPxDR),pPxCL),pPxCR);
			
			
			if (2*pPx < maxP)
				
				% IF PROBABILITY-VALUE IS RAPIDLY FALLING OFF AT CURRENT PIXEL
				newL = uint32(0);
				
			else
				% GET NEIGHBORHOOD (ADJACENT) PIXEL LABELS
				lPxUL = Linit(rowU, colL);
				lPxUC = Linit(rowU, colC);
				lPxUR = Linit(rowU, colR);
				lPxDL = Linit(rowD, colL);
				lPxDC = Linit(rowD, colC);
				lPxDR = Linit(rowD, colR);
				lPxCL = Linit(rowC, colL);
				lPxCR = Linit(rowC, colR);				
				
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
					% 					LrcmixBO = bitor(uint32(Lrow(:)) , bitshift(uint32(Lcol(:)), 15, 'uint32'));
					% 					newL = uint32(rowC + numRows*(colC-1));
				end
			end
		end
		
	end


% ==================================================
% LABEL-REFINEMENT
% ==================================================
	function newL = refinePixelLabel(lPx, pPx, rowC, colC, n)
		
		if (pPx <= foregroundMinProbability)
			newL = uint32(0);
		else
			
			% CALCULATE SUBSCRIPTS FOR SURROUNDING-PIXELS TO SAMPLE
			rowU = max( 1, rowC-1);
			rowD = min( numRows, rowC+1);
			colL = max( 1, colC-1);
			colR = min( numCols, colC+1);
			
			% GET NEIGHBORHOOD (ADJACENT-PIXELS) LABEL PROBABILITY-VALUES
			pPxUL = Pnew(rowU, colL, n);
			pPxUC = Pnew(rowU, colC, n);
			pPxUR = Pnew(rowU, colR, n);
			pPxDL = Pnew(rowD, colL, n);
			pPxDC = Pnew(rowD, colC, n);
			pPxDR = Pnew(rowD, colR, n);
			pPxCL = Pnew(rowC, colL, n);
			pPxCR = Pnew(rowC, colR, n);
			
			% FIND MAXIMUM P-VALUE
			maxP = max(max(max(max(max(max(max(max(...
				pPx,pPxUL),pPxUC),pPxUR),pPxDL),pPxDC),pPxDR),pPxCL),pPxCR);
			
			
			if (2*pPx < maxP)
				
				% IF PROBABILITY-VALUE IS RAPIDLY FALLING OFF AT CURRENT PIXEL
				newL = uint32(0);
				
			else
				% GET NEIGHBORHOOD (ADJACENT) PIXEL LABELS
				% 				lPxUL = Linit(rowU, colL);
				% 				lPxUC = Linit(rowU, colC);
				% 				lPxUR = Linit(rowU, colR);
				% 				lPxDL = Linit(rowD, colL);
				% 				lPxDC = Linit(rowD, colC);
				% 				lPxDR = Linit(rowD, colR);
				% 				lPxCL = Linit(rowC, colL);
				% 				lPxCR = Linit(rowC, colR);
				lPxUL = L(rowU, colL, n);
				lPxUC = L(rowU, colC, n);
				lPxUR = L(rowU, colR, n);
				lPxDL = L(rowD, colL, n);
				lPxDC = L(rowD, colC, n);
				lPxDR = L(rowD, colR, n);
				lPxCL = L(rowC, colL, n);
				lPxCR = L(rowC, colR, n);
				
				
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
					% 					LrcmixBO = bitor(uint32(Lrow(:)) , bitshift(uint32(Lcol(:)), 15, 'uint32'));
					% 					newL = uint32(rowC + numRows*(colC-1));
				end
			end
		end
		
	end







end














	
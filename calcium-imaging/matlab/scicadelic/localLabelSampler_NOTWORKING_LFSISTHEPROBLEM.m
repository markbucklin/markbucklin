function [Ln, P, Lenc, Lsize] = localLabelSampler(F, Ln, P, radiusRange, numRegionalSamples, bThresh)
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
[numRows, numCols, numFrames] = size(F);
numPixels = numRows*numCols;


% ==================================================
% FILL MISSING INPUTS WITH DEFAULTS
% ==================================================
if nargin < 2
	Ln = [];
end
if nargin < 3
	P = [];
end
if (nargin < 4) || isempty(radiusRange)
	% 	radiusRange = 10;
	radiusRange = [8 24];
end
if (nargin < 5) || isempty(numRegionalSamples)
	numRegionalSamples = 4;
end
if (nargin < 6) || isempty(bThresh)
	bThresh = fix(min(range(F,1),[],2) / 4);
end
if isempty(Ln)
	numPastLabels = uint32(0);
else
	numPastLabels = size(Ln,3);
end


% ==================================================
% SUBSCRIPTS INTO SHIFTED SURROUND
% ==================================================
rowSubs = gpuArray.colon(1,numRows)';
colSubs = gpuArray.colon(1,numCols);
frameSubs = reshape(gpuArray.colon(1, numFrames), 1,1,numFrames);


	

% ==================================================
% INIT/UPDATE FOREGROUND-PROBABILITY MATRIX -> P,U
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
	arrayfun( @computeForegroundBackgroundProbabilityUpdate,...
	F, rowSubs, colSubs, frameSubs, bThresh, radiusSample),...
	4) ./ actualNumSamples;

if ~isempty(P)
	Pnew = bsxfun(@plus, P, Pnew)./2;
end
% countThresh = actualNumSamples * 7;%(numFrames-1);
% 	Pn = repmat(single(sum(Pnew>countThresh, 3) - sum(Pnew<0, 3))./numFrames, 1, 1, numFrames);
% else



% ==================================================
% INITIALIZE LABEL-MATRIX -> L
% ==================================================
if isempty(Ln)
	[Lcol, Lrow] = meshgrid(1:numCols, 1:numRows);
	LrcmixBO = bitor(uint32(Lrow(:)) , bitshift(uint32(Lcol(:)), 16, 'uint32'));
	L = reshape(gpuArray(LrcmixBO), numRows, numCols);
elseif ismatrix(Ln)	
	L = Ln;
else
	L = arrayfun( @findLastNonZeroLabel, Pnew, rowSubs, colSubs);
	% do a L=Ln(:,:,end); mask=L>0; L = L.*mask + L(:,:,k).*(~mask);
end


% ==================================================
% PROPAGATE/SPREAD STRONGEST PIXEL LABELS -> Ln
% ==================================================
Ln = arrayfun( @propagateLabelLikelihood,...
	L, Pnew, rowSubs, colSubs, frameSubs);

% ==================================================
% ACCUMULATE LABEL VALUES -> COUNT, MIN, MAX, & MEAN
% ==================================================
[Lenc, Lsize] = getEncodedLabelSizeMeanMaxMin(Ln, F);

% L = Ln(:,:,end);
P = sum(Pnew,3)/numFrames;
% L = mode(Ln, 3);




% ##################################################
% SUB-FUNCTIONS
% ##################################################


	function [encL, szL] = getEncodedLabelSizeMeanMaxMin(Lmat, Fmat)
		Lnz = logical(Lmat);
		% Lidx = find(Lnz);
		Lframe = bsxfun(@times, uint16(Lnz), frameSubs);
		LmatRow = bitand( Lmat , uint32(65535));
		LmatCol = bitand( bitshift(Lmat, -16), uint32(65535));
		
		Lcnt = accumarray([LmatRow(Lnz), LmatCol(Lnz), Lframe(Lnz)],...
			1, [numRows, numCols, numFrames], @sum, 0, false);
		Lsum = accumarray([LmatRow(Lnz), LmatCol(Lnz), Lframe(Lnz)],...
			single(Fmat(Lnz)), [numRows, numCols, numFrames], @sum, single(0), false);
		Lmax = accumarray([LmatRow(Lnz), LmatCol(Lnz), Lframe(Lnz)],...
			single(Fmat(Lnz)), [numRows, numCols, numFrames], @max, single(0), false);
		Lmin = accumarray([LmatRow(Lnz), LmatCol(Lnz), Lframe(Lnz)],...
			single(Fmat(Lnz)), [numRows, numCols, numFrames], @min, single(0), false);
		Lsnz = (Lcnt>2) & (LmatRow>=1) & (LmatCol>=1);
		
		Lmix = [uint16(Lcnt(Lsnz)) , uint16(Lsum(Lsnz)./Lcnt(Lsnz)) , uint16(Lmax(Lsnz)) , uint16(Lmin(Lsnz)) ]';
		LmixTC = typecast(Lmix(:), 'double');
		
		encL = accumarray([LmatRow(Lsnz)+(numRows*(LmatCol(Lsnz)-1)) , Lframe(Lsnz)],...
			LmixTC, [numPixels , numFrames], [],  0, true);
		szL = uint16(Lcnt);
	end




% ##################################################
% STENCIL-OP SUB-FUNCTIONS -> RUNS ON GPU
% ##################################################

% ==================================================
% REGIONAL SIGNIFICANT DIFFERENCE COUNT
% ==================================================
	function uPx = computeForegroundBackgroundProbabilityUpdate(fPx, rowC, colC, n, b, r)
		
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
	function lPx = findLastNonZeroLabel(pPx, rowC, colC)
		
		if pPx>0
			k = numPastLabels;
			lPx = Ln(rowC,colC,k);
			while (lPx <= 0) && (k > 1)
				k = k-1;
				lPx = Ln(rowC,colC,k);
			end
		else
			lPx = uint32(0);
		end
		
	end



% ==================================================
% LABEL-PROBABILITY ESTIMATION & PROPAGATION
% ==================================================
	function newL = propagateLabelLikelihood(lPx, pPx, rowC, colC, n)
		
		if (pPx <= .5)
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
				lPxUL = L(rowU, colL);
				lPxUC = L(rowU, colC);
				lPxUR = L(rowU, colR);
				lPxDL = L(rowD, colL);
				lPxDC = L(rowD, colC);
				lPxDR = L(rowD, colR);
				lPxCL = L(rowC, colL);
				lPxCR = L(rowC, colR);
				
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
% HYBRID MEDIAN FILTER
% ==================================================
% 	function fPx = hybridMedFilt(fPx, rowC, colC, n)
%
% 		% GET CURRENT/CENTER PIXEL FROM F (read-only)
% 		% 		fPx = F(rowC, colC, n)
%
% 		% ------------------------------------------------
% 		% CALCULATE SUBSCRIPTS FOR ADJACENT/NEIGHBORING-PIXELS (8-CONNECTED)
% 		rowU = max( 1, rowC-1);
% 		rowD = min( numRows, rowC+1);
% 		colL = max( 1, colC-1);
% 		colR = min( numCols, colC+1);
%
% 		% GET IMMEDIATELY ADJACENT NEIGHBOR PIXELS
% 		fPxUL = F(rowU, colL, n); % X
% 		fPxUC = F(rowU, colC, n); % +
% 		fPxUR = F(rowU, colR, n); % X
% 		fPxDL = F(rowD, colL, n); % X
% 		fPxDC = F(rowD, colC, n); % +
% 		fPxDR = F(rowD, colR, n); % X
% 		fPxCL = F(rowC, colL, n); % +
% 		fPxCR = F(rowC, colR, n); % +
%
% 		% APPLY HYBRID MEDIAN FILTER (X+)
% 		if isinteger(fPxUL)
% 			mmHV = bitshift( max(min(fPxUC,fPxDC),min(fPxCL,fPxCR)), -1) ...
% 				+ bitshift( min(max(fPxUC,fPxDC),max(fPxCL,fPxCR)), -1);
% 			mmXX = bitshift( max(min(fPxUL,fPxDL),min(fPxUR,fPxDR)), -1) ...
% 				+ bitshift( min(max(fPxUL,fPxDL),max(fPxUR,fPxDR)), -1);
% 		else
% 			mmHV = (max(min(fPxUC,fPxDC),min(fPxCL,fPxCR)) ...
% 				+ min(max(fPxUC,fPxDC),max(fPxCL,fPxCR))) / 2;
% 			mmXX = (max(min(fPxUL,fPxDL),min(fPxUR,fPxDR)) ...
% 				+ min(max(fPxUL,fPxDL),max(fPxUR,fPxDR))) / 2;
% 		end
% 		fPx = min( min(max(fPx,mmHV),max(fPx,mmXX)), max(mmHV,mmXX));
% 	end









% ==================================================
% ENCODE LABEL WITH INTENSITY
% ==================================================
% 	function fEnc = encodeMinMaxMean(fPx, lPx, pPx)
%
% 		if pPx > 0
% 			fEnc = bitand( bitshift(uint64(fPx), 15), uint64(lPx));
% 		else
% 			fEnc = uint64(0);
% 		end
% 		% 		pEnc = uint64(pPx*255);
%
% 	end


% ##################################################
% ROI-ACCUMULATION SUB-FUNCTIONS
% ##################################################

% ==================================================
% PIXEL AVERAGE
% ==================================================
% 	function fEnc = encodeMinMaxMean(f)
% 		fEnc = sum(f)/length(f);
% 	end




end








% 		lPxUL = L(rowU, colL, n);
% 		lPxUC = L(rowU, colC, n);
% 		lPxUR = L(rowU, colR, n);
% 		lPxDL = L(rowD, colL, n);
% 		lPxDC = L(rowD, colC, n);
% 		lPxDR = L(rowD, colR, n);
% 		lPxCL = L(rowC, colL, n);
% 		lPxCR = L(rowC, colR, n);




% 		if (pPx <= .5) || (maxP <= .75)
% 		if (pPx <= 0) || (3*pPx < 2*maxP)


% if rand>.5
% L = max(Ln, [], 3);
% else
% 	L = min(Ln, [], 3);
% end

% 	Lrcmix = [uint16(Lrow(:)) , uint16(Lcol(:))]';
% 	LrcmixTC = typecast(Lrcmix(:),'uint32');
% 	L = uint32(bsxfun(@plus, bsxfun(@plus, rowSubs, numRows*(colSubs-1)), numPixels*(frameSubs-1)));
% 	L = gpuArray(uint32(bsxfun(@plus, (1:numRows)', numRows*(0:numCols-1))));

%
% Lnzmin = max( L, min(Ln,[],3));
% Lnzmax = min( L, max(Ln, [],3));
% L = max(Lnzmin, Lnzmax);

% 	LrowN = bitand( Ln, uint32(65535));
% 	k = numFrames;
% 	Lrow = LrowN(:,:,k);
% 	while (Lrow == 0) && (k > 0)
% 		k = k-1;
% 		Lrow = LrowN(:,:,k);
% 	end
% 	LcolN = bitand( bitshift(Ln, -15, 'uint32'), uint32(65535));
% 	k = numFrames;
% 	Lcol = LcolN(:,:,k);
% 	while (Lcol == 0) && (k > 0)
% 		k = k-1;
% 		Lcol = LcolN(:,:,k);
% 	end
%
% 	recLrow = Lrow(:,:,end);
% 	recLcol = Lcol(:,:,end);

% 			lPxRow = bitand( lPx , uint32(65535));
% 			lPxCol = bitand( bitshift(lPx, -15, 'uint32'), uint32(65535));







% 	fScale = single(1/intmax(classUnderlying(F)));
	% 	P = bsxfun(@times, (single(sum(C>countThresh, 3)) - single(sum(C<0, 3)))./numFrames , single(F));
	% 	P = int32(sum(C>countThresh, 3) - int32(sum(C<0, 3))) .* F;
	
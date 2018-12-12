function [F, peripheralDiffMax, peripheralDiffCount] = pixelNeighborhoodSampler(F, L, sampleRadius, bThresh)
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
% RESHAPE MULTI-FRAME INPUT TO 2D
% ==================================================
[numRows, numCols, numFrames] = size(F);


% ==================================================
% FILL MISSING INPUTS WITH DEFAULTS
% ==================================================
if nargin < 2
	L = [];
end
if nargin < 3
	sampleRadius = 10;
end
if nargin < 4
	bThresh = min(range(F,1),[],2);
end


% ==================================================
% SUBSCRIPTS INTO SHIFTED SURROUND
% ==================================================
rowSubs = gpuArray.colon(1,numRows)';
colSubs = gpuArray.colon(1,numCols);
frameSubs = reshape(gpuArray.colon(1, numFrames), 1,1,numFrames);


% ==================================================
% CALL ELEMENT-WISE FUNCTION/KERNEL ON GPU
% ==================================================
[F, peripheralDiffMax, peripheralDiffCount] = arrayfun( @comparePixelDifference, rowSubs, colSubs, frameSubs, bThresh, sampleRadius);


% ==================================================
% INITIALIZE LABEL-MATRIX
% ==================================================
if isempty(L)
	[L, labelMax] = bwlabel(bwmorph(any(peripheralDiffCount>7,3),'close'));
else
	labelMax = max(L(:));
end








% ##################################################
% ==================================================
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ==================================================
	function [fCC, fsd, ssdc] = comparePixelDifference( rowC, colC, n, b, r)
		
		% GET CURRENT/CENTER PIXEL FROM F (read-only)
		fCC = F(rowC, colC, n);
		
		% ------------------------------------------------ (adds 0.9ms/frame)
		% CALCULATE SUBSCRIPTS FOR ADJACENT/NEIGHBORING-PIXELS (8-CONNECTED)
		rowU = max( 1, rowC-1);
		rowD = min( numRows, rowC+1);
		colL = max( 1, colC-1);
		colR = min( numCols, colC+1);
		
		% GET IMMEDIATELY ADJACENT NEIGHBOR PIXELS
		faUL = F(rowU, colL, n); % X
		faUC = F(rowU, colC, n); % +
		faUR = F(rowU, colR, n); % X
		faDL = F(rowD, colL, n); % X
		faDC = F(rowD, colC, n); % +
		faDR = F(rowD, colR, n); % X
		faCL = F(rowC, colL, n); % +	
		faCR = F(rowC, colR, n); % +
		
		% APPLY HYBRID MEDIAN FILTER (X+)
		if isinteger(faUL)
			mmHV = bitshift( max(min(faUC,faDC),min(faCL,faCR)), -1) ...
				+ bitshift( min(max(faUC,faDC),max(faCL,faCR)), -1);
			mmXX = bitshift( max(min(faUL,faDL),min(faUR,faDR)), -1) ...
				+ bitshift( min(max(faUL,faDL),max(faUR,faDR)), -1);			
		else
			mmHV = (max(min(faUC,faDC),min(faCL,faCR)) ...
				+ min(max(faUC,faDC),max(faCL,faCR))) / 2;
			mmXX = (max(min(faUL,faDL),min(faUR,faDR)) ...
				+ min(max(faUL,faDL),max(faUR,faDR))) / 2;
		end
		fCC = min( min(max(fCC,mmHV),max(fCC,mmXX)), max(mmHV,mmXX));
		
		% ------------------------------------------------ (1.4ms/frame)
		% CALCULATE SUBSCRIPTS FOR SURROUNDING-PIXELS TO SAMPLE
		rowU = max( 1, rowC-r);
		rowD = min( numRows, rowC+r);
		colL = max( 1, colC-r);
		colR = min( numCols, colC+r);
		
		% COMPUTE DIFFERENCE BETWEEN CURRENT PIXEL & NON-LOCAL/REGIONAL SAMPLES 
		fCCfp = single(fCC);
		frUL = fCCfp - single(F(rowU, colL, n));
		frUC = fCCfp - single(F(rowU, colC, n));
		frUR = fCCfp - single(F(rowU, colR, n));
		frDL = fCCfp - single(F(rowD, colL, n));
		frDC = fCCfp - single(F(rowD, colC, n));
		frDR = fCCfp - single(F(rowD, colR, n));
		frCL = fCCfp - single(F(rowC, colL, n));			
		frCR = fCCfp - single(F(rowC, colR, n));
		
		% COUNT NUMBER & POLARITY OF SIGNIFICANT PIXEL INTENSITY DIFFERENCES
		ssdc = int8(...
			sign(frUL) * single(abs(frUL)>b) ...
			+ sign(frUC) * single(abs(frUC)>b) ...
			+ sign(frUR) * single(abs(frUR)>b) ...
			+ sign(frCL) * single(abs(frCL)>b) ...
			+ sign(frCR) * single(abs(frCR)>b) ...
			+ sign(frDL) * single(abs(frDL)>b) ...
			+ sign(frDC) * single(abs(frDC)>b) ...
			+ sign(frDR) * single(abs(frDR)>b) );
		
		% RETURN BEST PIXEL DIFFERENCE IF SIGNIFICANCE COUNT EXCEEDS MAJORITY COMPARISONS
		if (ssdc > 5)
			fsd = max( ...
				max(max(frUL,frUR),max(frDL,frDR)), ...
				max(max(frUC,frDC),max(frCL,frCR)));
		elseif (ssdc < -5)
			fsd = min( ...
				min(min(frUL,frUR),min(frDL,frDR)), ...
				min(min(frUC,frDC),min(frCL,frCR)));
		else
			fsd = single(0);
		end
			
			
	end



end











% fUL = F(rowU, colL, n);			fUC = F(rowU, colC, n);			fUR = F(rowU, colR, n);
% fCL = F(rowC, colL, n);			fCC = F(rowC, colC, n);			fCR = F(rowC, colR, n);
% fDL = F(rowD, colL, n);			fDC = F(rowD, colC, n);			fDR = F(rowD, colR, n);

% fnUL = F(rowU, colL, n);		fnUC = F(rowU, colC, n);		fnUR = F(rowU, colR, n);
% fnCL = F(rowC, colL, n);		fnCC = F(rowC, colC, n);		fnCR = F(rowC, colR, n);
% fnDL = F(rowD, colL, n);		fnDC = F(rowD, colC, n);		fnDR = F(rowD, colR, n);






% 
% fCC = fAdj(2,2);
% % 		fCC = F(rowC, colC, n);
% 
% % GET IMMEDIATELY ADJACENT NEIGHBOR PIXELS
% faUL = fAdj(1, 1); % X
% faUC = fAdj(1, 2); % +
% faUR = fAdj(1, 3); % X
% faDL = fAdj(1, 1); % X
% faDC = fAdj(3, 2); % +
% faDR = fAdj(3, 3); % X
% faCL = fAdj(2, 1); % +
% faCR = fAdj(2, 3); % +


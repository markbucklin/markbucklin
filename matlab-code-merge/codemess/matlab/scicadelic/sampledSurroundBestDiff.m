function [bestSignificanIntensityDiff, surroundSigDiffCount] = sampledSurroundBestDiff(F, sampleRadius, bThresh)
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
%
%	BENCHMARKS:
%		F: [1024x1024xN] 
%				N=64 -> 1.4 ms/frame
%				N=32 -> 1.4 ms/frame
%				N=16 -> 1.5 ms/frame
%				N=8	 -> 1.7 ms/frame




% ==================================================
% RESHAPE MULTI-FRAME INPUT TO 2D
% ==================================================
[numRows, numCols, numFrames] = size(F);


% ==================================================
% FILL MISSING INPUTS WITH DEFAULTS
% ==================================================
if nargin < 2
	sampleRadius = 10;
end
if nargin < 3
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
[bestSignificanIntensityDiff, surroundSigDiffCount] = arrayfun( @comparePixelDifference, rowSubs, colSubs, frameSubs, bThresh, sampleRadius);


% ==================================================
% RESHAPE & FORMAT OUTPUT
% ==================================================









% ##################################################
% ==================================================
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ==================================================
	function [fsd, ssdc] = comparePixelDifference( rowC, colC, n, b, r)
		
		% CALCULATE SUBSCRIPTS FOR SURROUNDING-PIXELS TO SAMPLE
		rowU = max( 1, rowC-r);
		rowD = min( numRows, rowC+r);
		colL = max( 1, colC-r);
		colR = min( numCols, colC+r);
		
		% GET CURRENT/CENTER PIXEL FROM F (read-only) (opportunity for median filter)
		fCC = single(F(rowC, colC, n));
		
		% COMPUTE DIFFERENCE BETWEEN CENTER & NON-LOCAL SURROUND PIXELS 
		fUL = fCC - single(F(rowU, colL, n));
		fUC = fCC - single(F(rowU, colC, n));
		fUR = fCC - single(F(rowU, colR, n));
		fCL = fCC - single(F(rowC, colL, n));			
		fCR = fCC - single(F(rowC, colR, n));
		fDL = fCC - single(F(rowD, colL, n));
		fDC = fCC - single(F(rowD, colC, n));
		fDR = fCC - single(F(rowD, colR, n));
		
		% COUNT NUMBER & POLARITY OF SIGNIFICANT PIXEL INTENSITY DIFFERENCES
		ssdc = int8(...
			sign(fUL) * single(abs(fUL)>b) ...
			+ sign(fUC) * single(abs(fUC)>b) ...
			+ sign(fUR) * single(abs(fUR)>b) ...
			+ sign(fCL) * single(abs(fCL)>b) ...
			+ sign(fCR) * single(abs(fCR)>b) ...
			+ sign(fDL) * single(abs(fDL)>b) ...
			+ sign(fDC) * single(abs(fDC)>b) ...
			+ sign(fDR) * single(abs(fDR)>b) );
		
		% RETURN BEST PIXEL DIFFERENCE IF SIGNIFICANCE COUNT EXCEEDS MAJORITY COMPARISONS
		if (ssdc > 5)
			fsd = max( ...
				max(max(fUL,fUR),max(fDL,fDR)), ...
				max(max(fUC,fDC),max(fCL,fCR)));
		elseif (ssdc < -5)
			fsd = min( ...
				min(min(fUL,fUR),min(fDL,fDR)), ...
				min(min(fUC,fDC),min(fCL,fCR)));
		else
			fsd = single(0);
		end
			
			
	end



end











% fUL = F(rowU, colL, n);			fUC = F(rowU, colC, n);			fUR = F(rowU, colR, n);
% fCL = F(rowC, colL, n);			fCC = F(rowC, colC, n);			fCR = F(rowC, colR, n);
% fDL = F(rowD, colL, n);			fDC = F(rowD, colC, n);			fDR = F(rowD, colR, n);








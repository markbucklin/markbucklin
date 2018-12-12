function F = hybridMedianFilterRunGpuKernel(F, rowSubs, colSubs, frameSubs)
% hybridMedianFilterRunGpuKernel
%
% Applies a combination of median-filtering and averaging on 2D or 3D gpuArray input.
%
%TODO:
% if ndims(F)>3
% 	[numRows, numCols, numChannels, numFrames] = size(F);
% else





% ==================================================
% GET DIMENSIONS OF INPUT INTENSITY IMAGE(s) - F
% ==================================================
[numRows, numCols, numFrames, numChannels] = size(F);


% ==================================================
% SUBSCRIPTS INTO SHIFTED SURROUND
% ==================================================
if nargin < 2
	rowSubs = int32(gpuArray.colon(1,numRows)');
	colSubs = int32(gpuArray.colon(1,numCols));
	frameSubs = int32(reshape(gpuArray.colon(1, numFrames), 1,1,numFrames));
	chanSubs =  int32(reshape(gpuArray.colon(1, numChannels), 1,1,1,numChannels));
end



% ==================================================
% CALL HYBRID-MEDIAN-FILTER GPU KERNEL
% ==================================================
% try
F = arrayfun( @hybridMedFiltSubFuncKernel, F, rowSubs, colSubs, frameSubs, chanSubs);

% catch
% 	rowSubs = gpuArray.colon(1,numRows)';
% 	colSubs = gpuArray.colon(1,numCols);
% 	frameSubs = reshape(gpuArray.colon(1, numFrames), 1,1,numFrames);
% 	F = arrayfun( @hybridMedFiltSubFuncKernel,...
% 	F, rowSubs, colSubs, frameSubs);
% end









% ##################################################
% STENCIL-OP SUB-FUNCTIONS -> RUNS ON GPU
% ##################################################

% ==================================================
% HYBRID MEDIAN FILTER
% ==================================================
	function fOut = hybridMedFiltSubFuncKernel(fCC, rowC, colC, frameC, chanC)
		
		% ------------------------------------------------
		% CALCULATE SUBSCRIPTS FOR ADJACENT/NEIGHBORING-PIXELS (8-CONNECTED)
		rowU = max( 1, rowC-1);
		rowD = min( numRows, rowC+1);
		colL = max( 1, colC-1);
		colR = min( numCols, colC+1);
		
		% GET IMMEDIATELY ADJACENT NEIGHBOR PIXELS
% 		fCC = F(rowC, colC, n);
		fUC = F(rowU, colC, frameC, chanC); % +
		fDC = F(rowD, colC, frameC, chanC); % +
		fUL = F(rowU, colL, frameC, chanC); % X
		fDL = F(rowD, colL, frameC, chanC); % X
		fCL = F(rowC, colL, frameC, chanC); % +		
		fUR = F(rowU, colR, frameC, chanC); % X
		fDR = F(rowD, colR, frameC, chanC); % X
		fCR = F(rowC, colR, frameC, chanC); % +
		
		% APPLY HYBRID MEDIAN FILTER (X+)
		mmHV = (max(min(fUC,fDC),min(fCL,fCR))/2 ...
			+ min(max(fUC,fDC),max(fCL,fCR))/2);
		mmXX = (max(min(fUL,fDL),min(fUR,fDR))/2 ...
			+ min(max(fUL,fDL),max(fUR,fDR))/2);
		fOut = fCC/2 + mmXX/4 + mmHV/4;
% 				fOut = fCC/3 + mmXX/3 + mmHV/3;
		% 		fOut = min( min(max(fCC,mmHV),max(fCC,mmXX)), max(mmHV,mmXX));

	end


end

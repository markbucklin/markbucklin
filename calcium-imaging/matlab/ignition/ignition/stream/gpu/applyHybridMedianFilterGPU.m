function F = applyHybridMedianFilterGPU(F)
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
[numRows, numCols, numChannels, numFrames] = size(F);


% ==================================================
% SUBSCRIPTS INTO SHIFTED SURROUND
% ==================================================
if nargin < 2
	rowSubs = int32(gpuArray.colon(1,numRows)');
	colSubs = int32(gpuArray.colon(1,numCols));
	frameSubs = int32(reshape(gpuArray.colon(1, numFrames), 1,1,1, numFrames));
	chanSubs =  int32(reshape(gpuArray.colon(1, numChannels), 1,1,numChannels));
end



% ==================================================
% CALL HYBRID-MEDIAN-FILTER GPU KERNEL
% ==================================================
% try
F = arrayfun( @hybridMedFiltSubFuncKernel, F, rowSubs, colSubs, chanSubs, frameSubs);

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
	function fOut = hybridMedFiltSubFuncKernel(f, rowIdx, colIdx, chanIdx, frameIdx)
		
		% ------------------------------------------------
		% CALCULATE SUBSCRIPTS FOR ADJACENT/NEIGHBORING-PIXELS (8-CONNECTED)
		rowU = max( 1, rowIdx-1);
		rowD = min( numRows, rowIdx+1);
		colL = max( 1, colIdx-1);
		colR = min( numCols, colIdx+1);
		
		% GET IMMEDIATELY ADJACENT NEIGHBOR PIXELS
% 		fCC = F(rowC, colC, n);
		fUC = F(rowU, colIdx, chanIdx, frameIdx); % +
		fDC = F(rowD, colIdx, chanIdx, frameIdx); % +
		fUL = F(rowU, colL, chanIdx, frameIdx); % X
		fDL = F(rowD, colL, chanIdx, frameIdx); % X
		fCL = F(rowIdx, colL, chanIdx, frameIdx); % +		
		fUR = F(rowU, colR, chanIdx, frameIdx); % X
		fDR = F(rowD, colR, chanIdx, frameIdx); % X
		fCR = F(rowIdx, colR, chanIdx, frameIdx); % +
		
		% APPLY HYBRID MEDIAN FILTER (X+)
		mmHV = (max(min(fUC,fDC),min(fCL,fCR))/2 ...
			+ min(max(fUC,fDC),max(fCL,fCR))/2);
		mmXX = (max(min(fUL,fDL),min(fUR,fDR))/2 ...
			+ min(max(fUL,fDL),max(fUR,fDR))/2);
		fOut = f/2 + mmXX/4 + mmHV/4;
% 				fOut = fCC/3 + mmXX/3 + mmHV/3;
		% 		fOut = min( min(max(fCC,mmHV),max(fCC,mmXX)), max(mmHV,mmXX));

	end


end

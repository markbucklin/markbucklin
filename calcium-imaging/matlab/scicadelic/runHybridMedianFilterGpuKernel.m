function F = runHybridMedianFilterGpuKernel(F)



% ==================================================
% GET DIMENSIONS OF INPUT INTENSITY IMAGE(s) - F
% ==================================================
[numRows, numCols, numFrames] = size(F);


% ==================================================
% SUBSCRIPTS INTO SHIFTED SURROUND
% ==================================================
rowSubs = gpuArray.colon(1,numRows)';
colSubs = gpuArray.colon(1,numCols);
frameSubs = reshape(gpuArray.colon(1, numFrames), 1,1,numFrames);


% ==================================================
% CALL HYBRID-MEDIAN-FILTER GPU KERNEL
% ==================================================
F = arrayfun( @hybridMedFiltSubFuncKernel,...
	F, rowSubs, colSubs, frameSubs);





% ##################################################
% STENCIL-OP SUB-FUNCTIONS -> RUNS ON GPU
% ##################################################

% ==================================================
% HYBRID MEDIAN FILTER
% ==================================================
	function fPx = hybridMedFiltSubFuncKernel(fPx, rowC, colC, n)
		
		% GET CURRENT/CENTER PIXEL FROM F (read-only)
		% 		fPx = F(rowC, colC, n)
		
		% ------------------------------------------------
		% CALCULATE SUBSCRIPTS FOR ADJACENT/NEIGHBORING-PIXELS (8-CONNECTED)
		rowU = max( 1, rowC-1);
		rowD = min( numRows, rowC+1);
		colL = max( 1, colC-1);
		colR = min( numCols, colC+1);
		
		% GET IMMEDIATELY ADJACENT NEIGHBOR PIXELS
		fPxUL = F(rowU, colL, n); % X
		fPxUC = F(rowU, colC, n); % +
		fPxUR = F(rowU, colR, n); % X
		fPxDL = F(rowD, colL, n); % X
		fPxDC = F(rowD, colC, n); % +
		fPxDR = F(rowD, colR, n); % X
		fPxCL = F(rowC, colL, n); % +
		fPxCR = F(rowC, colR, n); % +
		
		% APPLY HYBRID MEDIAN FILTER (X+)
		if isinteger(fPxUL)
			mmHV = bitshift( max(min(fPxUC,fPxDC),min(fPxCL,fPxCR)), -1) ...
				+ bitshift( min(max(fPxUC,fPxDC),max(fPxCL,fPxCR)), -1);
			mmXX = bitshift( max(min(fPxUL,fPxDL),min(fPxUR,fPxDR)), -1) ...
				+ bitshift( min(max(fPxUL,fPxDL),max(fPxUR,fPxDR)), -1);
		else
			mmHV = (max(min(fPxUC,fPxDC),min(fPxCL,fPxCR)) ...
				+ min(max(fPxUC,fPxDC),max(fPxCL,fPxCR))) / 2;
			mmXX = (max(min(fPxUL,fPxDL),min(fPxUR,fPxDR)) ...
				+ min(max(fPxUL,fPxDL),max(fPxUR,fPxDR))) / 2;
		end
		fPx = min( min(max(fPx,mmHV),max(fPx,mmXX)), max(mmHV,mmXX));
	end


end
function Q0 = reduceToLastLabelRunGpuKernel(Q, Qlock, rowSubs, colSubs)
% >> pixelLabelInitial = reduceToLastLabelRunGpuKernel(Q, Qlock)


% ============================================================
% PROCESS INPUT - FILL DEFAULTS
% ============================================================
[numRows, numCols, ~] = size(R);
if nargin < 3
	rowSubs = int32(gpuArray.colon(1,numRows)');
	colSubs = int32(gpuArray.colon(1,numCols));
end
if nargin < 2 
	Qlock = gpuArray.zeros(numRows,numCols,'uint32');
end



numPastLabels = size(Q,3);
if ~isempty(Q)	
	Q0 = arrayfun( @labelStackReductionKernel, Qlock, rowSubs, colSubs);	
	% do a L=Ln(:,:,end); mask=L>0; L = L.*mask + L(:,:,k).*(~mask);
end










% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################
	function qPx = labelStackReductionKernel( qLock, rowC, colC)
		
		qPx = qLock;
		if (qPx <= 0)
			k = numPastLabels;
			qPx = Q(rowC,colC,k);
			k = k-1;
			while (qPx <= 0) && (k > 1)
				qPx = Q(rowC,colC,k);
				k = k-1;
			end
			
			
		end
		
	end








end










% 				lPxIdx = lPxRow + numRows*(lPxCol-1);
% 			if (lPx > 0)
%
% 				lPxRow = bitand( lPx , uint32(65535));
% 				lPxCol = bitand( bitshift(lPx, -16), uint32(65535));
% 				pxLabelIncidence = labelIncidence(lPxRow,lPxCol);
% 				pxPeakIncidence = peakIncidence(lPxRow,lPxCol);
% 				if (pxLabelIncidence > 255) && (pxPeakIncidence > 127)
% 					lPxLocked = lPx;
% 				end
% 			end







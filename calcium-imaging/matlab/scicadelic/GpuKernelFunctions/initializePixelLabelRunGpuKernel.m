function Q0 = initializePixelLabelRunGpuKernel(R, Q, Qlock, rowSubs, colSubs)
% >> pixelLabelInitial = initializePixelLabelRunGpuKernel(R, Q, Qlock)


% ============================================================
% PROCESS INPUT - FILL DEFAULTS
% ============================================================
[numRows, numCols, ~] = size(R);
if nargin < 4
	rowSubs = int32(gpuArray.colon(1,numRows)');
	colSubs = int32(gpuArray.colon(1,numCols));
end
if nargin < 3 
	Qlock = gpuArray.zeros(numRows,numCols,'uint32');
end
% if nargin < 5
% 	peakIncidence = gpuArray.zeros(numRows,numCols,1,'uint16');
% end
% if nargin < 4
% 	labelIncidence = gpuArray.zeros(numRows,numCols,1,'uint16');
% end
if nargin < 2
	Q = [];
end
numPastLabels = size(Q,3);
	
if isempty(Q)
	[Qcol, Qrow] = meshgrid(colSubs, rowSubs);
	Qpack = bitor(uint32(Qrow(:)) , bitshift(uint32(Qcol(:)), 16));
	Q0 = reshape(Qpack, numRows, numCols);
	% elseif ~ismatrix(L)
	% 	L = repmat(L, 1, 1, numFrames);
else
	Q0 = arrayfun( @labelInitKernel, max(R,[],3), Qlock, rowSubs, colSubs);
	% 	[pixelLabelInitial, pixelLabelLocked] = arrayfun( @labelInitKernel, pixelLabelLocked, max(pixelLayerUpdate,[],3), rowSubs, colSubs);
	% 	[pixelLabelInitial, pixelLabelLocked] = arrayfun( @labelInitKernel, pixelLabelLocked, max(pixelLayerUpdate,[],3), rowSubs, colSubs);
	% 	L = arrayfun( @initializePixelLabel, Pnew, rowSubs, colSubs);
	% do a L=Ln(:,:,end); mask=L>0; L = L.*mask + L(:,:,k).*(~mask);
end


% if nargout > 1
% 	varargout{1} = pixelLabelLocked;
% end











% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################
	function qPx = labelInitKernel(rPx, qPxLocked, rowC, colC)
% 		function [lPx, lPxLocked] = labelInitKernel(lPxLocked, pPx, rowC, colC)
		
		qPx = qPxLocked;
		if (rPx > 0) && (qPx <= 0)
			k = numPastLabels;
			qPx = Q(rowC,colC,k);
			k = k-1;
			while (qPx <= 0) && (k > 1)
				qPx = Q(rowC,colC,k);
				k = k-1;
			end
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
		end
		
	end








end

% 				lPxIdx = lPxRow + numRows*(lPxCol-1);

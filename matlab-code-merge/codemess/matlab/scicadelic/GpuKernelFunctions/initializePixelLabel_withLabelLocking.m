function [pixelLabelInitial, varargout] = initializePixelLabelRunGpuKernel(...
	pixelLayerUpdate, lastLabel, labelIncidence, peakIncidence, pixelLabelLocked, rowSubs, colSubs)
% function pixelLabelInitial = initializePixelLabelRunGpuKernel(F, pixelLayerUpdate, lastLabel, pixelLabelLocked, rowSubs, colSubs)


% ============================================================
% PROCESS INPUT - FILL DEFAULTS
% ============================================================
[numRows, numCols, ~] = size(pixelLayerUpdate);
if nargin < 7
	rowSubs = gpuArray.colon(1,numRows)';
	colSubs = gpuArray.colon(1,numCols);	
end
if nargin < 6
	pixelLabelLocked = gpuArray.false(numRows,numCols);
end
if nargin < 5
	peakIncidence = gpuArray.zeros(numRows,numCols,1,'uint16');
end
if nargin < 4
	labelIncidence = gpuArray.zeros(numRows,numCols,1,'uint16');
end
if nargin < 3
	lastLabel = [];
end
numPastLabels = size(lastLabel,3);
	
if isempty(lastLabel)
	[Qcol, Qrow] = meshgrid(colSubs, rowSubs);
	Qpack = bitor(uint32(Qrow(:)) , bitshift(uint32(Qcol(:)), 16));
	pixelLabelInitial = reshape(Qpack, numRows, numCols);
	% elseif ~ismatrix(L)
	% 	L = repmat(L, 1, 1, numFrames);
else
	[pixelLabelInitial, pixelLabelLocked] = arrayfun( @labelInitKernel, pixelLabelLocked, max(pixelLayerUpdate,[],3), rowSubs, colSubs);
	% 	[pixelLabelInitial, pixelLabelLocked] = arrayfun( @labelInitKernel, pixelLabelLocked, max(pixelLayerUpdate,[],3), rowSubs, colSubs);
	% 	L = arrayfun( @initializePixelLabel, Pnew, rowSubs, colSubs);
	% do a L=Ln(:,:,end); mask=L>0; L = L.*mask + L(:,:,k).*(~mask);
end


if nargout > 1
	varargout{1} = pixelLabelLocked;
end











% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################
	function [lPx, lPxLocked] = labelInitKernel(lPxLocked, pPx, rowC, colC)
		
		lPx = lPxLocked;
		if (pPx > 0) && (lPx <= 0)
			k = numPastLabels;
			lPx = lastLabel(rowC,colC,k);
			while (lPx <= 0) && (k > 1)
				k = k-1;
				lPx = lastLabel(rowC,colC,k);
			end
			if (lPx > 0)
				
				lPxRow = bitand( lPx , uint32(65535));
				lPxCol = bitand( bitshift(lPx, -16), uint32(65535));
				pxLabelIncidence = labelIncidence(lPxRow,lPxCol);
				pxPeakIncidence = peakIncidence(lPxRow,lPxCol);
				if (pxLabelIncidence > 255) && (pxPeakIncidence > 127)
					lPxLocked = lPx;
				end
			end
		end
		
	end








end

% 				lPxIdx = lPxRow + numRows*(lPxCol-1);

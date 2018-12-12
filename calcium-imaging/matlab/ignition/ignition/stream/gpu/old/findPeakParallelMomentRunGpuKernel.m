function [uy, ux] = findPeakParallelMomentRunGpuKernel(XC, subPix)



% ============================================================
% MANAGE INPUT	& INITIALIZE DEFAULTS
% ============================================================
if nargin < 2
	subPix = 10;
end
[numRows, numCols, numFrames, numChannels] = size(XC);
rowSubs = int32(gpuArray.colon(1,numRows)');
colSubs = int32(gpuArray.colon(1,numCols));
frameSubs = int32(reshape(gpuArray.colon(1, numFrames), 1,1,numFrames));
chanSubs =  int32(reshape(gpuArray.colon(1, numChannels), 1,1,1,numChannels));
centerRow = floor(numRows/2) + 1;
centerCol = floor(numCols/2) + 1;
rowLim = int32(centerRow + fix(numRows*[-.25 .25]));
colLim = int32(centerCol + fix(numCols*[-.25 .25]));


% ============================================================
% FIND COARSE (INTEGER) SUBSCRIPTS OF PHASE-CORRELATION PEAK (INTEGER-PRECISION MAXIMUM)
% ============================================================
[colMax,colMaxIdx] = max(XC,[],1);
[rowMax,rowMaxIdx] = max(XC,[],2);

[crMax, crMaxIdx] = max(colMax,[],2);
[rcMax, rcMaxIdx] = max(rowMax,[],1);

d = single(5);
r = floor(d/2);
dRowSubs = int32(gpuArray.colon(-r,r)');
dColSubs = int32(gpuArray.colon(-r,r));

[UY,UX] = arrayfun(@parallelMomentKernel, dRowSubs, dColSubs, frameSubs, chanSubs);

uy = mean(mean(UY));
ux = mean(mean(UX));







% ##################################################
% STENCIL-OP KDE SUB-FUNCTION -> RUNS ON GPU
% ##################################################
	function [uymom,uxmom] = parallelMomentKernel( dRowIdx, dColIdx, frameIdx, chanIdx)
		
		% APPLY WINDOWING OPERATION TO VALID PIXELS AROUND CENTER
		rowIdx = rcMaxIdx(1,1,frameIdx,chanIdx) - dRowIdx;
		colIdx = crMaxIdx(1,1,frameIdx,chanIdx) - dColIdx;
		if (rowIdx<rowLim(1)) || (rowIdx>rowLim(2)) || (colIdx<colLim(1)) || (colIdx>colLim(2))
			uymom = single(0);
			uxmom = single(0);
			
		else
			xcmax = max(crMax(1,1,frameIdx,chanIdx), rcMax(1,1,frameIdx,chanIdx));
			num = single(0);
			den = single(0);			
						
			for k = -r:r
				rowOffset = single(dRowIdx) + k;
				xc = XC(int32(k)+rowIdx, colIdx, frameIdx, chanIdx)/xcmax;
				num = num + rowOffset*xc;
				den = den + xc;
			end
			uymom = num/den + single(rowIdx) - single(centerRow);% - single(dRowIdx);
			
			num = single(0);
			den = single(0);
			k = single(0)-d-single(dColIdx);
			for k = -r:r
				colOffset = single(dColIdx) + k;
				xc = XC(rowIdx, colIdx+int32(k), frameIdx, chanIdx)/xcmax;
				num = num + colOffset*xc;
				den = den + xc;				
			end
			uxmom = num/den + single(colIdx) - single(centerCol);% - single(dColIdx);
			
			
		end
		
	end





end





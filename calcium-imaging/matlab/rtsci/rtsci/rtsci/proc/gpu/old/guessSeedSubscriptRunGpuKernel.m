function [Gy,Gx,Gu] = guessSeedSubscriptRunGpuKernel(Iy,Ix,radialDisplacement)
%DYSFUNCTIONAL
%
% BENCHMARK: ~  ms/frame/displacement (tested with 16 frame chunk)



% ============================================================
% PROCESS INPUT - FILL DEFAULTS
% ============================================================
[numRows, numCols, numDisplacements] = size(Iy);
rowSubs = int32(gpuArray.colon(1,numRows)');
colSubs = int32(gpuArray.colon(1,numCols));
if nargin < 3
	radialDisplacement = [];
end
if isempty(radialDisplacement)
		radialDisplacement = single(gpuArray.colon(1,numDisplacements)); %single([1 2 3 4 6 8 10]);
% 	radialDisplacement = gpuArray(single(2.^(0:5)));
end




% ============================================================
% CALL SUB-FUNCTION USING GPU/ARRAYFUN (COMPILES CUDA KERNEL)
% ============================================================
[Gy,Gx, Gu] = arrayfun( @guessSeedKernel, rowSubs, colSubs);












% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################

	function [gy,gx,gu] = guessSeedKernel(rowIdx, colIdx)
		
		
		% INITIALIZE INFORMATION VECTOR ADDITION & INFORMATION MAGNITUDE
		iy = single(Iy(rowIdx,colIdx,1));
		ix = single(Ix(rowIdx,colIdx,1));
		iymax = iy;
		ixmax = ix;
		
		
		% Y
		k=1;
		while (abs(iy) >= .5*abs(iymax)) && (k < numDisplacements)
			k = k+1;
			iy = single(Iy(rowIdx,colIdx,k));
			iyupdate = abs(iy) >= abs(iymax);
			iymax = single(iyupdate)*iy + single(~iyupdate)*iymax;  %max( abs(iymax), abs(iy));
		end
		if abs(iymax) > .7
			gy = single(radialDisplacement(k) * sign(iymax) / 2);
			yguess = true;
		else
			gy = single(0);
			yguess = false;
		end
		
		% X
		k=1;
		while (abs(ix) >= .5*abs(ixmax)) && (k < numDisplacements)
			k = k+1;
			ix = single(Ix(rowIdx,colIdx,k));
			ixupdate = abs(ix) >= abs(ixmax);
			ixmax = single(ixupdate)*ix + single(~ixupdate)*ixmax;  %max( abs(iymax), abs(iy));
		end		
		if abs(ixmax) > .7
			gx = single(radialDisplacement(k) * sign(ixmax) / 2);
			xguess = true;
		else
			gx = single(0);
			xguess = false;
		end
		
		guy = gy + single(colIdx);
		gux = gx + single(rowIdx);
		
		if xguess || yguess		
			gu = bitor( uint32(guy) , bitshift(uint32(gux), 16));
		else
			gu = uint32(0);
		end
		
	end







end








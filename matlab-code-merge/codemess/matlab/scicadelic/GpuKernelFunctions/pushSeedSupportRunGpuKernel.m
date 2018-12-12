function S0 = pushSeedSupportRunGpuKernel(Iy,Ix,Isym,N)
%DYSFUNCTIONAL
%
% BENCHMARK: ~  ms/frame/displacement (tested with 16 frame chunk)



% ============================================================
% PROCESS INPUT - FILL DEFAULTS
% ============================================================
[numRows, numCols, numDisplacements] = size(Iy);
rowSubs = int32(gpuArray.colon(1,numRows)');
colSubs = int32(gpuArray.colon(1,numCols));
% Sy = gpuArray.zeros(numRows,numCols, 'int8');
% Sx = gpuArray.zeros(numRows,numCols, 'int8');
Sy = sum(Iy,3);
Sx = sum(Ix,3);

%TODO Imax rather than 3
%% S0 = sum(Isym,3);%max(Isym,[],3)
% S0 = gpuArray.zeros(numRows,numCols, 'single');


S0 = gpuArray.zeros(numRows,numCols,2, 'single');
suppDir = reshape([1 2],1,1,2);
Sd = cat(3,Sy,Sx);

% ============================================================
% CALL SUB-FUNCTION USING GPU/ARRAYFUN (COMPILES CUDA KERNEL)
% ============================================================
n=0;
while n < N
	n=n+1;
	% 	[Sy,Sx, S0] = arrayfun( @pushSupportKernel, rowSubs, colSubs);
	[Sd,S0] = arrayfun( @pushSupportDirKernel, rowSubs, colSubs, suppDir, n);
end



% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################
	
	% DIRECTIONS IN PARALLEL
	function [sd,s0] = pushSupportDirKernel(rowIdx, colIdx, dIdx, k)
		
		% GET S0 & SD
		s0 = S0(rowIdx,colIdx,dIdx);
		isX = dIdx == 2;		
		sd = Sd(rowIdx,colIdx,dIdx);
		
		% GET SD- & SD+
		if isX
			sdm = Sd(rowIdx, max(1,colIdx-1), dIdx);
			sdp = Sd(rowIdx, min(numCols,colIdx+1), dIdx);
		else
			sdm = Sd(max(1,rowIdx-1), colIdx, dIdx);
			sdp = Sd(min(numRows,rowIdx+1), colIdx, dIdx);
		end
		
		
		if sdm >= 3*k && sdp <= -3*k
			s0 = s0 + single(1);
		else
			sd = sd + sdm + sdp;
		end
		
	end

% BOTH DIRECTIONS AT ONCE
	function [sy,sx,s0] = pushSupportKernel(rowIdx, colIdx)
		
		
		s0 = S0(rowIdx,colIdx);
		sy = Sy(rowIdx,colIdx);
		sx = Sx(rowIdx,colIdx);
		
		syu = Sy(max(1,rowIdx-1), colIdx);
		syd = Sy(min(numRows,rowIdx+1), colIdx);
		sxl = Sx(rowIdx, max(1,colIdx-1));
		sxr = Sx(rowIdx, min(numCols,colIdx+1));
				
		if syu > 3 && syd < -3
			s0 = s0 + single(1);
		else
			sy = sy + syu + syd;
		end
		
		if sxl > 3 && sxr < -3
			s0 = s0 + single(1);
		else
			sx = sx + sxl + sxr;
		end
		
		
		% 		if s0<.1
		
		% 			return
		% 		else
		% 			syu = Sy(max(1,rowIdx-1), colIdx);
		% 			syd = Sy(min(numRows,rowIdx+1), colIdx);
		% 			sxl = Sx(rowIdx, max(1,colIdx-1));
		% 			sxr = Sx(rowIdx, min(numCols,colIdx+1));

			
			
			% 			sy = sy + single(syu>k*syd) - single(syd<k*syu);
			% 			sx = sx + single(sxl>k*sxr) - single(sxl<k*sxr);
			
			% 			if max(abs(syu),abs(syd)) < s0
			% 				sy = sy + syu + syd;
			% 			end
			% 			if max(abs(sxl),abs(sxr)) < s0
			% 				sx = sx + sxl + sxr;
			% 			end
			
			% 		end
		
		
		
	end




end
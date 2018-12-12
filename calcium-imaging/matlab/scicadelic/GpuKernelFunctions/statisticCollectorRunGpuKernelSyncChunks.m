function stat = statisticCollectorRunGpuKernelSyncChunks(F, stat) %todo:mask
% STATISTICCOLLECTORRUNGPUKERNELSYNCCHUNKS
% 
% Redundant function:
%
% SEE ALSO:
%			STATISTICCOLLECTORRUNGPUKERNEL
%


% ============================================================
% INFO ABOUT INPUT
% ============================================================
fpType = 'single';
F = ongpu(F);
[numRows, numCols, numFrames] = size(F);
rowSubs = gpuArray.colon(1,numRows)';
colSubs = gpuArray.colon(1,numCols);
frameSubs = reshape(gpuArray.colon(1, numFrames), 1,1,numFrames);


% ============================================================
% INITIALIZE STATISTICS (MIN/MAX & CENTRAL MOMENTS)
% ============================================================
if (nargin < 2)	
	% FROM 1ST INPUT: PRESUMING 1ST CALL (FIRST CHUNK IS SAMPLED TWICE)
	Na = single(numFrames);
	sMin = min(F,[],3);
	sMax = max(F,[],3);
	sM1 = cast(mean(F,3),fpType);
	Ffp = cast(F, fpType);
	sM2 = moment(Ffp, 2, 3);
	sM3 = moment(Ffp, 3, 3);
	sM4 = moment(Ffp, 4, 3);
	
else
	% FROM 2ND INPUT ARGUMENT: PRESUMED OUTPUT OF PREVIOUS CALL
	Na = stat.N;
	sMin = stat.Min;
	sMax = stat.Max;
	sM1 = stat.M1;
	sM2 = stat.M2;
	sM3 = stat.M3;
	sM4 = stat.M4;
	
end


% ============================================================
% RUN KERNEL
% ============================================================
Nkm1 = Na;
k=1;
while k <= numFrames
	[sMin,sMax,sM1,sM2,sM3,sM4,Nkm1] = arrayfun(@statUpdateKernelFcn, rowSubs, colSubs, frameSubs(k), Nkm1);
	k=k+1;
end


% STORE MOMENTS IN STRUCTURE (might need cumsum or cumdiff)
stat.N = Nkm1;
stat.Min = sMin;
stat.Max = sMax;
stat.M1 = sM1;
stat.M2 = sM2;
stat.M3 = sM3;
stat.M4 = sM4;



% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################
	function [pxMin,pxMax,pxM1,pxM2,pxM3,pxM4,n] = statUpdateKernelFcn(rowC, colC, frameC, na)
		
		% GET PIXEL
		fCC = F(rowC,colC,frameC);
		fCCfp = single(fCC);
		
		% COUNT/WEIGHT
		n = na + 1;
				
		% UPDATE MAX & MIN
		pxMin = min(fCC, sMin(rowC,colC));
		pxMax = max(fCC, sMax(rowC,colC));
		
		% RETRIEVE PRIOR CENTRAL MOMENTS
		m1 = sM1(rowC,colC);
		m2 = sM2(rowC,colC);
		m3 = sM3(rowC,colC);
		m4 = sM4(rowC,colC);
		
		% UPDATE CENTRAL MOMENTS
		d = fCCfp - m1;
		dk = d/n;
		dk2 = dk^2;
		s = d*dk*(n-1);
		pxM1 = m1 + dk;
		pxM4 = m4 + s*dk2*(n^2-3*n+3) + 6*dk2*m2 - 4*dk*m3;
		pxM3 = m3 + s*dk*(n-2) - 3*dk*m2;
		pxM2 = m2 + s;
		
	end


end

















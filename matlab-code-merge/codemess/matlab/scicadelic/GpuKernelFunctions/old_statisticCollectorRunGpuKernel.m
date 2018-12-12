function [stat, dStat] = statisticCollectorRunGpuKernel(F, stat)
% ALSO RETURN DSTAT ARRAY (same size as input, F) WITH FRAME CONTRIBUTION TO CHANGE IN STATISTIC


% INFO ABOUT INPUT
fpType = 'single';
F = cast(F, fpType);
[numRows, numCols, numFrames] = size(F);


% INITIALIZE STAT STRUCTURE
if isa(F, 'gpuArray')
	initZeroMat = gpuArray.zeros(numRows, numCols, 1, fpType);
else
	initZeroMat = zeros(numRows, numCols, 1, fpType);
end
if (nargin < 2)	
	stat.N = initZeroMat;
	stat.Min = min(F, [], 3);
	stat.Max = max(F, [], 3);
	stat.M1 = initZeroMat;
	stat.M2 = initZeroMat;
	stat.M3 = initZeroMat;
	stat.M4 = initZeroMat;
end

% PREALLOCATE DSTAT STRUCTURE
% dStat.N(:,:,numFrames) = initZeroMat;
dStat.Min(:,:,numFrames) = cast(initZeroMat, 'like', F);
dStat.Max(:,:,numFrames) = cast(initZeroMat, 'like', F);
dStat.M1(:,:,numFrames) = initZeroMat;
dStat.M2(:,:,numFrames) = initZeroMat;
dStat.M3(:,:,numFrames) = initZeroMat;
dStat.M4(:,:,numFrames) = initZeroMat;


% REMOVE INITIAL STATISTICS FROM STRUCTURE
N = stat.N;
fMin = stat.Min;
fMax = stat.Max;
fM1 = stat.M1;
fM2 = stat.M2;
fM3 = stat.M3;
fM4 = stat.M4;


% RUN KERNEL ONE FRAME AT A TIME & COLLECT CHANGES
% for k = 1:numFrames
% [dfMin,dfMax,dfM1,dfM2,dfM3,dfM4,dN] = arrayfun(@statUpdateKernelFcn, F(:,:,k), fMin,fMax,fM1,fM2,fM3,N);

[dfMin,dfMax,dfM1,dfM2,dfM3,dfM4] = arrayfun(@statUpdateKernelFcn, F,fMin,fMax,fM1,fM2,fM3,N);
% dStat.N(:,:,k) = dN;
% dStat.Min(:,:,k) = dfMin;
% dStat.Max(:,:,k) = dfMax;
% dStat.M1(:,:,k) = dfM1;
% dStat.M2(:,:,k) = dfM2;
% dStat.M3(:,:,k) = dfM3;
% dStat.M4(:,:,k) = dfM4;

% dStat.N = dN;
dStat.Min = dfMin;
dStat.Max = dfMax;
dStat.M1 = dfM1;
dStat.M2 = dfM2;
dStat.M3 = dfM3;
dStat.M4 = dfM4;

% fMin = fMin + sum(dfMin, 3);
% fMax = fMax + sum(dfMax, 3);
% fM1 = fM1 + sum(dfM1, 3);
% fM2 = fM2 + sum(dfM2, 3);
% fM3 = fM3 + sum(dfM3, 3);
% fM4 = fM4 + sum(dfM4, 3);
% N = N + sum(dN, 3);
% end

% UPDATE STRUCTURE (might need cumsum or cumdiff)
stat.N = N + 1;
stat.Min = min(F, [], 3); %min( fMin, min(F, [],3));
stat.Max = max(F, [], 3); %max( fMax, max(F, [], 3));
stat.M1 = fM1 + dfM1(:,:,end);
stat.M2 = fM2 + dfM2(:,:,end);
stat.M3 = fM3 + dfM3(:,:,end);
stat.M4 = fM4 + dfM4(:,:,end);

% stat.M1 = fM1 + sum(dfM1, 3);
% stat.M2 = fM2 + sum(dfM2, 3);
% stat.M3 = fM3 + sum(dfM3, 3);
% stat.M4 = fM4 + sum(dfM4, 3);




% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################
	function [dmin,dmax,dm1,dm2,dm3,dm4] = statUpdateKernelFcn(fPx, pxmin, pxmax, m1, m2, m3, na)
		
		% COUNT/WEIGHT
		dn = 1;
		n = na + dn;
		
		% UPDATE MAX & MIN
		dmin = fPx - min(fPx, pxmin);
		dmax = fPx - max(fPx, pxmax);
		
		% UPDATE CENTRAL MOMENTS
		d = single(fPx) - m1;
		dk = d/n;
		dk2 = dk^2;
		s = d*dk*(n-1);
		dm1 = dk;
		dm4 = s*dk2*(n^2-3*n+3) + 6*dk2*m2 - 4*dk*m3;
		dm3 = s*dk*(n-2) - 3*dk*m2;
		dm2 = s;
		
	end


end







% function [pxMin,pxMax,pxM1,pxM2,pxM3,pxM4,n] = statUpdateKernelFcn(fPx, rowC, colC, frameC, na)
%
% 		% COUNT/WEIGHT
% 		n = na + 1;
%
% 		% UPDATE MAX & MIN
% 		pxMin = min(fPx, sMin(rowC,colC,frameC));
% 		pxMax = max(fPx, sMax(rowC,colC,frameC));
%
% 		% RETRIEVE PRIOR CENTRAL MOMENTS
% 		m1 = sM1(rowC,colC,frameC);
% 		m2 = sM2(rowC,colC,frameC);
% 		m3 = sM3(rowC,colC,frameC);
% 		m4 = sM4(rowC,colC,frameC);
%
% 		% UPDATE CENTRAL MOMENTS
% 		d = fPx - m1;
% 		dk = d/n;
% 		dk2 = dk^2;
% 		s = d*dk*(n-1);
% 		pxM1 = m1 + dk;
% 		pxM4 = m4 + s*dk2*(n^2-3*n+3) + 6*dk2*m2 - 4*dk*m3;
% 		pxM3 = m3 + s*dk*(n-2) - 3*dk*m2;
% 		pxM2 = m2 + s;
%
% 	end








% 		initZeroVal = zeros(1,fpTime);

% dStatInitZeroMat = repmat(initZeroMat, 1, 1, numFrames);
% dStat.N = repmat(initZeroVal, 1, 1, numFrames);
% dStat.Min = dStatInitZeroMat; %repmat(min(cast(F, fpType), [], 3), 1,1,numFrames);
% dStat.Max = dStatInitZeroMat; %repmat(max(cast(F, fpType), [], 3), 1,1,numFrames);
% dStat.M1 = dStatInitZeroMat;
% dStat.M2 = dStatInitZeroMat;
% dStat.M3 = dStatInitZeroMat;
% dStat.M4 = dStatInitZeroMat;


% rowSubs = gpuArray.colon(1,numRows)';
% colSubs = gpuArray.colon(1,numCols);
% frameSubs = reshape(gpuArray.colon(1, numFrames), 1,1,numFrames);
% 	frameNum = frameSubs(k);

% 		initZeroVal = gpuArray.zeros(1,fpType);
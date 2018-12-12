function [dStat, varargout] = differentialMomentGeneratorRunGpuKernel(Fin, stat)
% RETURNS DSTAT ARRAY (same size as input, F) WITH FRAME CONTRIBUTION TO CHANGE IN STATISTIC
% - Will also return update to cumulative moment structure, STAT


% ============================================================
% INFO ABOUT INPUT
% ============================================================
fpType = 'single';
F = cast(Fin, fpType);
[numRows, numCols, ~, ~] = size(F);

% INITIALIZE CUMULATIVE MOMENT STRUCTURE
initZeroMat = gpuArray.zeros(numRows, numCols, 1, fpType);
if (nargin < 2)
	stat.N = initZeroMat;
	stat.M1 = initZeroMat;
	stat.M2 = initZeroMat;
	stat.M3 = initZeroMat;
	stat.M4 = initZeroMat;
end

% REMOVE INITIAL STATISTICS FROM STRUCTURE
N = stat.N;
fM1 = stat.M1;
fM2 = stat.M2;
fM3 = stat.M3;
fM4 = stat.M4;

% RUN KERNEL ON ALL FRAMES SIMULTANEOUSLY & COLLECT CHANGE INITIAL STATISTIC
[dfM1,dfM2,dfM3,dfM4] = arrayfun(@statUpdateKernelFcn, F,fM1,fM2,fM3,N);

% FILL DIFFERENTIAL MOMENT STRUCTURE (OUTPUT)
dStat.M1 = dfM1;
dStat.M2 = dfM2;
dStat.M3 = dfM3;
dStat.M4 = dfM4;

% PROVIDE UPDATED CUMULATIVE MOMENT STRUCTURE IF 2ND OUTPUT REQUESTED
if nargout > 1
	stat.N = N + 1;
	stat.M1 = fM1 + mean(dfM1, 3);
	stat.M2 = fM2 + mean(dfM2, 3);
	stat.M3 = fM3 + mean(dfM3, 3);
	stat.M4 = fM4 + mean(dfM4, 3);
	varargout{1} = stat;
end






% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################
	function [dm1,dm2,dm3,dm4] = statUpdateKernelFcn(fPx, m1, m2, m3, na)
		
		% COUNT/WEIGHT
		n = na + 1;
		
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


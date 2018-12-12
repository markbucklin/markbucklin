function stat = statisticCollectorRunGpuKernel(Fin, stat)
% STATISTICCOLLECTORRUNGPUKERNEL
% 
% USAGE:
%			>> stat = statisticCollectorRunGpuKernel(F);
%			>> stat = statisticCollectorRunGpuKernel(F, stat);
%
% SEE ALSO:
%			COMPUTENONSTATIONARITYRUNGPUKERNEL, DIFFERENTIALMOMENTGENERATORRUNGPUKERNEL SCICADELIC.STATISTICCOLLECTOR
%
% Mark Bucklin










% ============================================================
% INFO ABOUT INPUT
% ============================================================
fpType = 'single';
F = ongpu(Fin);
[numRows,numCols,numFrames,numChannels] = size(F);
rowSubs = int32(gpuArray.colon(1,numRows)');
colSubs = int32(gpuArray.colon(1,numCols));
chanSubs =  int32(reshape(gpuArray.colon(1, numChannels), 1,1,1,numChannels));



if (nargin >= 2)
	% ============================================================
	% RUN KERNEL WITH GIVEN INITIALIZATION STATS
	% ============================================================
	
	% FROM 2ND INPUT ARGUMENT: PRESUMED OUTPUT OF PREVIOUS CALL
	N = single(stat.N);
	fMin = stat.Min;
	fMax = stat.Max;
	fM1 = stat.M1;
	fM2 = stat.M2;
	fM3 = stat.M3;
	fM4 = stat.M4;
	
	
	% ============================================================
	% CALL CUDA-KERNEL-GENERATING SUBFUNCTION: SEQUENTIAL STATISTIC UPDATES
	% ============================================================
	[fMin,fMax,fM1,fM2,fM3,fM4] = arrayfun(@statUpdateLoopInternalKernelFcn, rowSubs, colSubs, chanSubs, N);
	
else
	% ============================================================
	% INITIALIZE STATISTICS (MIN/MAX & CENTRAL MOMENTS)
	% ============================================================
	N = single(numFrames);
	fMin = min(F,[],3);
	fMax = max(F,[],3);
	
	% MOMENTS MEASURED ON 1ST INPUT: PRESUMING 1ST CALL
	Ffp = cast(F, fpType);
	fM1 = mean(Ffp, 3);
	fM2 = moment(Ffp, 2, 3);
	fM3 = moment(Ffp, 3, 3);
	fM4 = moment(Ffp, 4, 3);
	
end




% STORE MOMENTS IN STRUCTURE
stat.N = N + single(numFrames);
stat.Min = fMin;
stat.Max = fMax;
stat.M1 = fM1;
stat.M2 = fM2;
stat.M3 = fM3;
stat.M4 = fM4;











% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################
	function [fmin,fmax,m1,m2,m3,m4] = statUpdateLoopInternalKernelFcn(rowC, colC, chanC, na)
		
		% ---------------------------------------
		% RETRIEVE INITIAL VALUES FROM INPUT
		% ---------------------------------------
		
		% RETRIEVE MAX & MIN
		fmin = fMin(rowC,colC,1,chanC);
		fmax = fMax(rowC,colC,1,chanC);
		
		% RETRIEVE PRIOR CENTRAL MOMENTS
		m1 = fM1(rowC,colC,1,chanC);
		m2 = fM2(rowC,colC,1,chanC);
		m3 = fM3(rowC,colC,1,chanC);
		m4 = fM4(rowC,colC,1,chanC);
		
		% INITIALIZE N
		n = single(na);
		
		% ---------------------------------------
		% LOOP THROUGH SEQUENTIAL FRAMES FOR 1-BY-1-UPDATE
		% ---------------------------------------
		k = single(0);
		while k < numFrames
			
			% UPDATE SAMPLE INDICES (USUALLY TEMPORAL)
			k = k + 1;
			n = na + k; % TODO: allow mask/conditional input
			
			% GET PIXEL SAMPLE
			fint = F(rowC,colC,k,chanC);
			f = single(fint);
			
			% UPDATE MIN/MAX
			fmin = min(fint, fmin);
			fmax = max(fint, fmax);
			
			% UPDATE CENTRAL MOMENTS % TODO: check that order is ok... m1->m4->m3->m2
			d = f - m1;
			dk = d/n;
			dk2 = dk^2;
			s = d*dk*(n-1);
			m1 = m1 + dk;
			m4 = m4 + s*dk2*(n^2-3*n+3) + 6*dk2*m2 - 4*dk*m3;
			m3 = m3 + s*dk*(n-2) - 3*dk*m2;
			m2 = m2 + s;
			
		end
		
	end



end



























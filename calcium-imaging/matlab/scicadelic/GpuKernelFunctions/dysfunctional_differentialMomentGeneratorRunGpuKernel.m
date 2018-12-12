function [dstat, stat] = differentialMomentGeneratorRunGpuKernel(Fin, stat)
% DIFFERENTIALMOMENTGENERATORRUNGPUKERNEL
% 
% DESCRIPTION:
%			Returns dstat array (same size as input, f) with frame contribution to change in statistic
%			- Will also return update to cumulative moment structure, STAT
% 
%
% Returns dstat array (same size as input, f) with frame contribution to change in statistic
% - Will also return update to cumulative moment structure, STAT
% 
% USAGE:
%			>> [dstat, stat] = differentialMomentGeneratorRunGpuKernel(F);
%			>> [dstat, stat] = differentialMomentGeneratorRunGpuKernel(F, stat);
%
% SEE ALSO:
%			COMPUTENONSTATIONARITYRUNGPUKERNEL, STATISTICCOLLECTORRUNGPUKERNEL, SCICADELIC.STATISTICCOLLECTOR
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
frameSubs = int32(reshape(gpuArray.colon(1, numFrames), 1,1,numFrames));
chanSubs =  int32(reshape(gpuArray.colon(1, numChannels), 1,1,1,numChannels));



if (nargin >= 2)
	% ============================================================
	% RUN KERNEL WITH GIVEN INITIALIZATION STATS
	% ============================================================
	
	% FROM 2ND INPUT ARGUMENT: PRESUMED OUTPUT OF PREVIOUS CALL
	% 	N = single(stat.N);
	N = single(stat.N);
	fMin = stat.Min;
	fMax = stat.Max;
	fM1 = stat.M1;
	fM2 = stat.M2;
	fM3 = stat.M3;
	fM4 = stat.M4;
	
	% RUN INCREMENTAL UPDATE KERNEL
	updateFineGrain = any(N(:) <= max(1024, numFrames^2));
	if updateFineGrain
		% CALL KERNEL TO COMPUTE TRUE INCREMENTAL UPDATE TO CENTRAL MOMENTS
		[dM1,dM2,dM3,dM4] = arrayfun(@sequentialDifferentialKernelFcn, rowSubs, colSubs, frameSubs, chanSubs, N);
		
		% UPDATE CENTRAL MOMENTS FOR USE IN NEXT FRAME
		[fMin,fMax,fM1,fM2,fM3,fM4] = arrayfun(@statUpdateLoopInternalKernelFcn, rowSubs, colSubs, chanSubs, N);
		
	else
		% CALL KERNEL TO COMPUTE CHUNKED INCREMENTAL UPDATE TO CENTRAL MOMENTS
		[dM1,dM2,dM3,dM4] = arrayfun(@chunkedParallelDifferentialKernelFcn, F, fM1, fM2, fM3, N);
		
		% CALL SEPARATE REDUNDANT KERNEL TO COMPUTE NEW CENTRAL MOMENTS
		[fMin,fMax,fM1,fM2,fM3,fM4] = arrayfun(@statUpdateLoopInternalKernelFcn, rowSubs, colSubs, chanSubs, N);
		
	end
			
else
	% ============================================================
	% INITIALIZE STATISTICS (MIN/MAX & CENTRAL MOMENTS)
	% ============================================================
	N = single(numFrames); % TODO: use 1, 0 or numFrames to smooth first input
	fMin = min(F,[],3);
	fMax = max(F,[],3);
		
	% MOMENTS MEASURED ON 1ST INPUT: PRESUMING 1ST CALL
	Ffp = cast(F, fpType);
	fM1 = mean(Ffp, 3);
	fM2 = moment(Ffp, 2, 3);
	fM3 = moment(Ffp, 3, 3);
	fM4 = moment(Ffp, 4, 3);
	
	% CALL KERNEL TO COMPUTE TRUE INCREMENTAL UPDATE TO CENTRAL MOMENTS
	[dM1,dM2,dM3,dM4] = arrayfun(@sequentialDifferentialKernelFcn, rowSubs, colSubs, frameSubs, chanSubs, N);
	
end








% ============================================================
% STORE OUTPUT IN STRUCTURES -> STAT & DSTAT
% ============================================================

% N UPDATE
stat.N = N + single(numFrames);
stat.Min = fMin;
stat.Max = fMax;

% MOMENTS IN STRUCTURE OF STATIC STATISTICS --> (USED FOR NEXT INPUT)
stat.M1 = fM1;
stat.M2 = fM2;
stat.M3 = fM3;
stat.M4 = fM4;

% FILL DIFFERENTIAL-MOMENT (NON-STATIONARITY) STRUCTURE --> (OUTPUT)
dstat.M1 = dM1;
dstat.M2 = dM2;
dstat.M3 = dM3;
dstat.M4 = dM4;












% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################
	function [dm1,dm2,dm3,dm4] = sequentialDifferentialKernelFcn(rowC, colC, frameC, chanC, na)
		
		% RETRIEVE PRIOR CENTRAL MOMENTS
		m1 = fM1(rowC,colC,1,chanC);
		m2 = fM2(rowC,colC,1,chanC);
		m3 = fM3(rowC,colC,1,chanC);
		m4 = fM4(rowC,colC,1,chanC);
		
		% INITIALIZE OUTPUT
		dm1 = single(0);
		dm2 = single(0);
		dm3 = single(0);
		dm4 = single(0);
				
		% LOOP THROUGH SEQUENTIAL FRAMES FOR 1-BY-1-UPDATE		
		k = single(0);
		n = single(na);
		while k < frameC
			
			% UPDATE SAMPLE INDICES (USUALLY TEMPORAL)
			k = k + 1;
			n = single(na + k);
			
			% GET PIXEL SAMPLE
			fint = F(rowC,colC,k,chanC);
			f = single(fint);
			
			% COMPUTE DIFFERENTIAL UPDATE TO CENTRAL MOMENTS
			d = f - m1;
			dk = d/n;
			dk2 = dk^2;
			s = d*dk*(n-1);
			dm1 = dk;
			dm4 = s*dk2*(n^2-3*n+3) + 6*dk2*m2 - 4*dk*m3;
			dm3 = s*dk*(n-2) - 3*dk*m2;
			dm2 = s;
			
			% COMPUTE CUMULATIVE UPDATE TO CENTRAL MOMENTS
			m1 = m1 + dm1;
			m4 = m4 + dm4;
			m3 = m3 + dm3;
			m2 = m2 + dm2;			
			
		end
		
		% NORMALIZE BY VARIANCE & SAMPLE NUMBER
		sqrtm2 = sqrt(m2);
		sqrtn = sqrt(n);
		dm2 = sqrt(dm2)/sqrtn;
		dm3 = dm3*sqrtn/(sqrtm2^3);
		dm4 = dm4*n/(sqrtm2^4);
		
	end
	
	function [dm1,dm2,dm3,dm4] = chunkedParallelDifferentialKernelFcn(f, m1, m2, m3, na)
		
		% RETRIEVE PRIOR CENTRAL MOMENTS
		n = na + 1;
		
		% PRECOMPUTE & CACHE SOME VALUES FOR SPEED
		d = single(f) - m1;
		dk = d/n;
		dk2 = dk^2;
		s = d*dk*(n-1);
		
		% COMPUTE DIFFERENTIAL UPDATE TO CENTRAL MOMENTS
		dm1 = dk;
		dm4 = s*dk2*(n^2-3*n+3) + 6*dk2*m2 - 4*dk*m3;
		dm3 = s*dk*(n-2) - 3*dk*m2;
		dm2 = s;
		
		% NORMALIZE BY VARIANCE & SAMPLE NUMBER
		sqrtm2 = sqrt(m2 + s);
		sqrtn = sqrt(n);
		dm2 = sqrt(dm2)/sqrtn;
		dm3 = dm3*sqrtn/(sqrtm2^3);
		dm4 = dm4*n/(sqrtm2^4);
		
		
	end

	function [fmin,fmax,m1,m2,m3,m4] = statUpdateLoopInternalKernelFcn(rowC, colC, chanC, na)
				
		% INITIALIZE N
		n = single(na);
		
		% RETRIEVE MAX & MIN
		fmin = fMin(rowC,colC,1,chanC);
		fmax = fMax(rowC,colC,1,chanC);
		
		% RETRIEVE PRIOR CENTRAL MOMENTS
		m1 = fM1(rowC,colC,1,chanC);
		m2 = fM2(rowC,colC,1,chanC);
		m3 = fM3(rowC,colC,1,chanC);
		m4 = fM4(rowC,colC,1,chanC);
		
		
		% ---------------------------------------
		% LOOP THROUGH SEQUENTIAL FRAMES FOR 1-BY-1-UPDATE
		% ---------------------------------------
		k = single(0);
		while k < numFrames
			
			% UPDATE SAMPLE INDICES (USUALLY TEMPORAL)
			k = k + 1;
			n = n + 1; % TODO: allow mask/conditional input
			
			% GET PIXEL SAMPLE
			fint = F(rowC,colC,k,chanC);
			f = single(fint);
						
			% PRECOMPUTE & CACHE SOME VALUES FOR SPEED
			d = f - m1;
			dk = d/n;
			dk2 = dk^2;
			s = d*dk*(n-1);
			
			% UPDATE CENTRAL MOMENTS % TODO: check that order is ok... m1->m4->m3->m2
			m1 = m1 + dk;
			m4 = m4 + s*dk2*(n^2-3*n+3) + 6*dk2*m2 - 4*dk*m3;
			m3 = m3 + s*dk*(n-2) - 3*dk*m2;
			m2 = m2 + s;
			
			% UPDATE MIN & MAX
			fmin = min(fmin, fint);
			fmax = max(fmax, fint);			
			
		end
		
	end









end


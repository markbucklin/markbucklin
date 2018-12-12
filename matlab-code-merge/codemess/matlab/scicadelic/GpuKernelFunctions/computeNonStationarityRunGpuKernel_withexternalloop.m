function [dstat, stat] = computeNonStationarityRunGpuKernel(Fin, stat)
% COMPUTENONSTATIONARITYRUNGPUKERNEL
%
% Returns dstat array (same size as input, f) with frame contribution to change in statistic
% - Will also return update to cumulative moment structure, STAT
% 
% USAGE:
%			>> [dstat, stat] = computeNonStationarityRunGpuKernel(F);
%			>> [dstat, stat] = computeNonStationarityRunGpuKernel(F, stat);
%
% SEE ALSO:
%			DIFFERENTIALMOMENTGENERATORRUNGPUKERNEL, STATISTICCOLLECTORRUNGPUKERNEL, SCICADELIC.STATISTICCOLLECTOR
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
	N = stat.N;
	fM1 = stat.M1;
	fM2 = stat.M2;
	fM3 = stat.M3;
	fM4 = stat.M4;
			
else
	% ============================================================
	% INITIALIZE STATISTICS (MIN/MAX & CENTRAL MOMENTS)
	% ============================================================
	N = single(numFrames); % TODO: use 1, 0 or numFrames to smooth first input
		
	% MOMENTS MEASURED ON 1ST INPUT: PRESUMING 1ST CALL
	Ffp = cast(F, fpType);
	fM1 = mean(Ffp, 3);
	fM2 = moment(Ffp, 2, 3);
	fM3 = moment(Ffp, 3, 3);
	fM4 = moment(Ffp, 4, 3);
	
end


loopExternal = false;
if ~loopExternal
	% ============================================================
	% RUN INTERNAL LOOPING INCREMENTAL UPDATE KERNEL
	% ============================================================
	
	% CALL KERNEL TO COMPUTE INCREMENTAL (DIFFERENTIAL?) UPDATE TO CENTRAL MOMENTS
	[dM1,dM2,dM3,dM4] = arrayfun(@nonStationaryKernelFcn, rowSubs, colSubs, frameSubs, chanSubs, N);
	
	% UPDATE CENTRAL MOMENTS FOR USE IN NEXT FRAME
	fM1 = fM1 + sum(dM1,3);
	fM2 = fM2 + sum(dM2,3);
	fM3 = fM3 + sum(dM3,3);
	fM4 = fM4 + sum(dM4,3);
	
else
	% ============================================================
	% RUN EXTERNAL LOOPING INCREMENTAL UPDATE KERNEL
	% ============================================================
	% INITIALIZE DIFF-MOMENT ARRAYS
	k=0;
	dM1 = gpuArray.zeros(numRows, numCols, numFrames, numChannels, fpType);
	dM2 = gpuArray.zeros(numRows, numCols, numFrames, numChannels, fpType);
	dM3 = gpuArray.zeros(numRows, numCols, numFrames, numChannels, fpType);
	dM4 = gpuArray.zeros(numRows, numCols, numFrames, numChannels, fpType);
	
	while k < numFrames
		
		% INCREMENT K
		k = k + 1;
		Nk = N + k;
		
		% CALL KERNEL TO COMPUTE INCREMENTAL (DIFFERENTIAL?) UPDATE TO CENTRAL MOMENTS
		[dM1k,dM2k,dM3k,dM4k,fM1,fM2,fM3,fM4] = arrayfun(@nonStationaryExtLoopKernelFcn, F(:,:,k,:),fM1,fM2,fM3,fM4,Nk);
		
		% FILL DIFF-MOMENT ARRAYS
		dM1(:,:,k,:) = dM1k;
		dM2(:,:,k,:) = dM2k;
		dM3(:,:,k,:) = dM3k;
		dM4(:,:,k,:) = dM4k;
		
	end
	
	
end







% ============================================================
% STORE OUTPUT IN STRUCTURES -> STAT & DSTAT
% ============================================================

% MOMENTS IN STRUCTURE OF STATIC STATISTICS --> (USED FOR NEXT INPUT)
stat.N = N + single(numFrames);
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
	function [dm1,dm2,dm3,dm4] = nonStationaryKernelFcn(rowC, colC, frameC, chanC, na)
		
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
		k=0;
		while k < frameC
			
			% UPDATE SAMPLE INDICES (USUALLY TEMPORAL)
			k = k + 1;
			n = na + k;
			
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
	end
	function [dm1,dm2,dm3,dm4,m1,m2,m3,m4] = nonStationaryExtLoopKernelFcn(fint,m1,m2,m3,m4,n)
		
		% CONVERT PIXEL SAMPLE TO FLOATING POINT
		f = single(fint);
		% 		n = N + k;
		
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











% 	function [fmin,fmax,m1,m2,m3,m4,n] = statUpdateLoopInternalKernelFcn(rowC, colC, frameC, chanC, na)
% 		
% 		
% 		% RETRIEVE PRIOR CENTRAL MOMENTS
% 		m1 = fM1(rowC,colC,1,chanC);
% 		m2 = fM2(rowC,colC,1,chanC);
% 		m3 = fM3(rowC,colC,1,chanC);
% 		m4 = fM4(rowC,colC,1,chanC);
% 		
% 		% INITIALIZE N
% 		n = single(na);
% 		
% 		% ---------------------------------------
% 		% LOOP THROUGH SEQUENTIAL FRAMES FOR 1-BY-1-UPDATE
% 		% ---------------------------------------
% 		k=0;
% 		while k < numFrames
% 			
% 			% UPDATE SAMPLE INDICES (USUALLY TEMPORAL)
% 			k = k + 1;
% 			n = na + k; % TODO: allow mask/conditional input
% 			
% 			% GET PIXEL SAMPLE
% 			fint = F(rowC,colC,k,chanC);
% 			f = single(fint);
% 			
% 			% UPDATE MIN/MAX
% 			fmin = min(fint, fmin);
% 			fmax = max(fint, fmax);
% 			
% 			% UPDATE CENTRAL MOMENTS % TODO: check that order is ok... m1->m4->m3->m2
% 			d = f - m1;
% 			dk = d/n;
% 			dk2 = dk^2;
% 			s = d*dk*(n-1);
% 			m1 = m1 + dk;
% 			m4 = m4 + s*dk2*(n^2-3*n+3) + 6*dk2*m2 - 4*dk*m3;
% 			m3 = m3 + s*dk*(n-2) - 3*dk*m2;
% 			m2 = m2 + s;
% 		end
% 		
% 	end


% ============================================================
% NON-STATIONARITY-(DIFFERENTIAL-MOMENT)-KERNEL
% ============================================================
% 	function [dm1,dm2,dm3,dm4,n] = nonStationaryKernelFcn(rowC, colC, frameC, chanC, na)
% 		
% 		% GET PIXEL
% 		fint = F(rowC,colC,frameC,chanC);
% 		f = single(fint);
% 		
% 		% COUNT/WEIGHT
% 		n = na + 1;
% 		
% 		% RETRIEVE PRIOR CENTRAL MOMENTS
% 		m1 = fM1(rowC,colC,1,chanC);
% 		m2 = fM2(rowC,colC,1,chanC);
% 		m3 = fM3(rowC,colC,1,chanC);
% 		m4 = fM4(rowC,colC,1,chanC);
% 		
% 		% COMPUTE DIFFERENTIAL UPDATE CENTRAL MOMENTS
% 		d = f - m1;
% 		dk = d/n;
% 		dk2 = dk^2;
% 		s = d*dk*(n-1);
% 		dm1 = dk;
% 		dm4 = s*dk2*(n^2-3*n+3) + 6*dk2*m2 - 4*dk*m3;
% 		dm3 = s*dk*(n-2) - 3*dk*m2;
% 		dm2 = s;
% 		
% 	end




end















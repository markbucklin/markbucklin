function stat = statisticUpdateRunGpuKernel(F, stat)
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
% F = ongpu(Fin);
% [numRows,numCols,numFrames,numChannels] = size(F);
[numRows,numCols,numFrames] = size(F);
rowSubs = int32(gpuArray.colon(1,numRows)');
colSubs = int32(gpuArray.colon(1,numCols));
% chanSubs =  int32(reshape(gpuArray.colon(1, numChannels), 1,1,1,numChannels));



if (nargin >= 2)
	% ============================================================
	% RUN KERNEL WITH GIVEN INITIALIZATION STATS
	% ============================================================
	
	% FROM 2ND INPUT ARGUMENT: PRESUMED OUTPUT OF PREVIOUS CALL
	N = single(stat.N);
	fMin = stat.Min;
	fMax = stat.Max;
	fM1 = single(stat.M1);
	fM2 = single(stat.M2);
	fM3 = single(stat.M3);
	fM4 = single(stat.M4);
	
	% UPDATE CENTRAL MOMENTS
	if numFrames >= 1
		% 		N = gpuArray(int32(N));
		[fMin,fMax,fM1,fM2,fM3,fM4] = arrayfun(@statUpdateKernelFcn,...
			fMin,fMax,fM1,fM2,fM3,fM4,N, rowSubs, colSubs);
	end
			
else
	% ============================================================
	% INITIALIZE STATISTICS (MIN/MAX & CENTRAL MOMENTS)
	% ============================================================
	N = gpuArray.zeros(1,'single'); % TODO: use 1, 0 or numFrames to smooth first input
	fMin = min(F,[],3);
	fMax = max(F,[],3);
		
	% MOMENTS MEASURED ON 1ST INPUT: PRESUMING 1ST CALL
	Ffp = single(F);
	fM1 = single(mean(Ffp, 3));
	fM2 = single(moment(Ffp, 2, 3));
	fM3 = single(moment(Ffp, 3, 3));
	fM4 = single(moment(Ffp, 4, 3));
	
end




% ============================================================
% STORE OUTPUT IN STRUCTURE -> STAT 
% ============================================================

% N UPDATE
stat.N = single(N) + single(numFrames);
stat.Min = fMin;
stat.Max = fMax;

% MOMENTS IN STRUCTURE OF STATIC STATISTICS --> (USED FOR NEXT INPUT)
stat.M1 = fM1;
stat.M2 = fM2;
stat.M3 = fM3;
stat.M4 = fM4;













% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################

	function [fmin,fmax,m1,m2,m3,m4] = statUpdateKernelFcn(fmin,fmax,m1,m2,m3,m4,n, rowC, colC)
				
		% INITIALIZE N
		% 		n = single(N);
		
		% 		% RETRIEVE MAX & MIN
		% 		fmin = fMin(rowC,colC);
		% 		fmax = fMax(rowC,colC);
		%
		% 		% RETRIEVE PRIOR CENTRAL MOMENTS
		% 		m1 = fM1(rowC,colC);
		% 		m2 = fM2(rowC,colC);
		% 		m3 = fM3(rowC,colC);
		% 		m4 = fM4(rowC,colC);
		
		
		% ---------------------------------------
		% LOOP THROUGH SEQUENTIAL FRAMES FOR 1-BY-1-UPDATE
		% ---------------------------------------
		k = int32(0);
		while k < numFrames
			
			% UPDATE SAMPLE INDICES (USUALLY TEMPORAL)
			k = k + 1;
			n = n + 1; % TODO: allow mask/conditional input
			
			% GET PIXEL SAMPLE
			f = F(rowC,colC,k);
						
			% PRECOMPUTE & CACHE SOME VALUES FOR SPEED
			d = single(f) - m1;
			dk = d/n;
			dk2 = dk^2;
			s = d*dk*(n-1);
			
			% UPDATE CENTRAL MOMENTS % TODO: check that order is ok... m1->m4->m3->m2
			m1 = m1 + dk;
			m4 = m4 + s*dk2*(n.^2-3*n+3) + 6*dk2*m2 - 4*dk*m3;
			m3 = m3 + s*dk*(n-2) - 3*dk*m2;
			m2 = m2 + s;
			
			% UPDATE MIN & MAX
			fmin = min(fmin, f);
			fmax = max(fmax, f);			
			
		end
		
	end









end








% 
% 
% 
% 
% 
% 
% % RETRIEVE MAX & MIN
% fmin = fMin(rowC,colC,1,chanC);
% fmax = fMax(rowC,colC,1,chanC);
% 
% % RETRIEVE PRIOR CENTRAL MOMENTS
% m1 = fM1(rowC,colC,1,chanC);
% m2 = fM2(rowC,colC,1,chanC);
% m3 = fM3(rowC,colC,1,chanC);
% m4 = fM4(rowC,colC,1,chanC);
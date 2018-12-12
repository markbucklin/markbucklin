function [Fout, stat] = gemanMcClureNormalizationRunGpuKernel(F, stat)
% GEMANMCCLURENORMALIZATIONRUNGPUKERNEL
%
% DESCRIPTION:
%			Returns normalized image data
%			- Will also return update to cumulative moment structure, STAT
%
%
%
% USAGE:
%			>> [Fnorm, stat] = getStatisticDifferentialGPU(F);
%			>> [Fnorm, stat] = getStatisticDifferentialGPU(F, stat);
%
% SEE ALSO:
%			COMPUTENONSTATIONARITYRUNGPUKERNEL, UPDATESTATISTICSGPU, IGNITION.STATISTICCOLLECTOR
%
% Mark Bucklin







% ============================================================
% INFO ABOUT INPUT
% ============================================================
[numRows,numCols,numFrames,numChannels] = size(F);
rowSubs = int32(gpuArray.colon(1,numRows)');
colSubs = int32(gpuArray.colon(1,numCols));
frameSubs = int32(reshape(gpuArray.colon(1, numFrames), 1,1,numFrames));
chanSubs =  int32(reshape(gpuArray.colon(1, numChannels), 1,1,1,numChannels));

% DEFAULT EMPTY STAT STRUCT
if nargin < 2
	stat = [];
end

% TIME-CONSTANT FOR SUPPRESSION OF EARLY FRAMES
N0 = single(numFrames);



if ~isempty(stat)
	% ============================================================
	% RUN INCREMENTAL UPDATE KERNEL WITH GIVEN STATS
	% ============================================================
	
	% FROM 2ND INPUT ARGUMENT: PRESUMED OUTPUT OF PREVIOUS CALL
	N = single(stat.N);
	M1 = stat.M1;
	M2 = stat.M2;
	numSamples = single(numFrames);
	k0 = int32(0);
	
	% COMPUTE CENTRAL MOMENTS BALANCING ACCURACY AND SPEED
	% 	updateFineGrain = (N(1) <= 1024);
	%
	% 	if updateFineGrain
	% CALL KERNEL TO COMPUTE TRUE INCREMENTAL UPDATE TO CENTRAL MOMENTS (more accurate at low sample-size)
	% 		Fout = arrayfun(@sequentialVarianceKernel, rowSubs, colSubs, frameSubs, chanSubs);
	Fout = single(F);
	kFrame = k0;
	while kFrame < numSamples
		kFrame = kFrame + 1;
		[Fout(:,:,kFrame,:), M1, M2, N] = arrayfun(@externalLoopComboKernel, Fout(:,:,kFrame,:), M1, M2, N);
	end
	
	% 	else
	% 		% CALL KERNEL TO COMPUTE CHUNKED INCREMENTAL UPDATE TO CENTRAL MOMENTS (faster)
	% 		Fout = arrayfun(@chunkedVarianceKernel, F, M1, M2, N);
	% 		[M1,M2] = arrayfun(@centralMomentUpdateKernel,M1,M2,N,rowSubs,colSubs,chanSubs); %new
	% 		N = N + numSamples;% new
	% 	end
	
	% UPDATE CENTRAL MOMENTS FOR USE IN NEXT FRAME
	% 	[M1,M2] = arrayfun(@centralMomentUpdateKernel,M1,M2,N,rowSubs,colSubs,chanSubs);
	% 	N = N + numSamples
	
	
else
	% ============================================================
	% INITIALIZE STATISTICS (MIN/MAX & CENTRAL MOMENTS)
	% ============================================================
	
	N = gpuArray.ones(1,'single');
	
	% MOMENTS MEASURED ON 1ST INPUT: PRESUMING 1ST CALL
	% 	M1 = single(F(:,:,1,:));
	% 	M2 = single(F(:,:,1,:)-F(:,:,2,:)).^2;
	M1 = single(mean(F,3));
	M2 = single(moment(F,2,3));
	numSamples = single(numFrames);
	k0 = int32(0);
	
	Fout = single(F);
	kFrame = k0;
	while kFrame < numSamples
		kFrame = kFrame + 1;
		[Fout(:,:,kFrame,:), M1, M2, N] = arrayfun(@externalLoopComboKernel, Fout(:,:,kFrame,:), M1, M2, N);
	end
	
	% CALL KERNEL TO COMPUTE TRUE INCREMENTAL UPDATE TO CENTRAL MOMENTS
	% 	Fout = arrayfun(@sequentialVarianceKernel, rowSubs, colSubs, frameSubs, chanSubs);
	
	% UPDATE CENTRAL MOMENTS FOR USE IN NEXT FRAME (moved from above)
	% 	[M1,M2] = arrayfun(@centralMomentUpdateKernel,M1,M2,N,rowSubs,colSubs,chanSubs);
	% 	N = N + numSamples
	
end



% ============================================================
% STORE OUTPUT IN STRUCTURES -> STAT & DSTAT
% ============================================================

% N UPDATE
stat.N = single(N);% + numSamples; %single(numFrames);

% MOMENTS IN STRUCTURE OF STATIC STATISTICS --> (USED FOR NEXT INPUT)
stat.M1 = M1;
stat.M2 = M2;













% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################
	function f = sequentialVarianceKernel(rowIdx, colIdx, frameIdx, chanIdx)
		
		% RETRIEVE PRIOR CENTRAL MOMENTS
		m1 = M1(rowIdx,colIdx,1,chanIdx);
		m2 = M2(rowIdx,colIdx,1,chanIdx);
		
		% LOOP THROUGH SEQUENTIAL FRAMES FOR 1-BY-1-UPDATE
		k = int32(0);
		n = single(N);
		f = single(0);
		
		while k < frameIdx
			
			% UPDATE SAMPLE INDICES (USUALLY TEMPORAL)
			k = k + 1;
			n = n + 1;
			
			% GET PIXEL SAMPLE
			f = single(F(rowIdx,colIdx,k,chanIdx));
			
			% COMPUTE UPDATE TO 1ST TWO CENTRAL MOMENTS
			d = f - m1;
			dk = d/n;
			s = d*dk*(n-1);
			m1 = m1 + dk;
			m2 = m2 + s;
			
		end
		
		% COMPUTE VARIANCE & NORMALIZE SAMPLE
		% 		a = 1 - exp(-n/N0);
		s2 = m2/max(1,n-1);%/a;
		f2 = f^2;
		f = f2/(f2+s2);
		
		
		
	end

	function [f,m1,m2,n] = externalLoopComboKernel(f, m1, m2, n)
		
		% UPDATE N
		n = n + 1;
		
		% PRECOMPUTE & CACHE SOME VALUES FOR SPEED
		d = single(f) - m1;
		dk = d/n;
		s = d*dk*(n-1);
		
		% COMPUTE DIFFERENTIAL UPDATE TO CENTRAL MOMENTS
		m1 = m1 + dk;
		m2 = m2 + s;
		
		% COMPUTE VARIANCE & NORMALIZE SAMPLE
		% 		a = 1 - exp(-n/N0);
		s2 = m2/max(1,n-1);%/a;
		f2 = f^2;
		f = f2/(f2+s2);
		
		
	end

	function f = chunkedVarianceKernel(fin, m1, m2, n)
		
		% RETRIEVE PRIOR CENTRAL MOMENTS
		n = n + 1;
		f = single(fin);
		
		% PRECOMPUTE & CACHE SOME VALUES FOR SPEED
		d = single(f) - m1;
		dk = d/n;
		s = d*dk*(n-1);
		
		% COMPUTE DIFFERENTIAL UPDATE TO CENTRAL MOMENTS
		m2 = m2 + s;
		
		% COMPUTE VARIANCE & NORMALIZE SAMPLE
		s2 = m2/max(1,n-1);
		f2 = f^2;
		f = f2/(f2+s2);
		
		
	end

	function [m1,m2] = centralMomentUpdateKernel(m1,m2,n,rowIdx,colIdx,chanIdx)
		% REDUNDANT, BUT OFTEN FASTER THAN INDEXING INTO LARGE CHUNKED ARRAY
		
		% ---------------------------------------
		% LOOP THROUGH SEQUENTIAL FRAMES FOR 1-BY-1-UPDATE
		% ---------------------------------------
		k = k0;
		while k < numSamples
			
			% UPDATE SAMPLE INDICES (USUALLY TEMPORAL)
			k = k + 1;
			n = n + 1; % TODO: allow mask/conditional input
			
			% GET PIXEL SAMPLE
			f = F(rowIdx,colIdx,k,chanIdx);
			
			% PRECOMPUTE & CACHE SOME VALUES FOR SPEED
			d = single(f) - m1;
			dk = d/n;
			s = d*dk*(n-1);
			
			% UPDATE CENTRAL MOMENTS
			m1 = m1 + dk;
			m2 = m2 + s;
			
		end
		
	end









end

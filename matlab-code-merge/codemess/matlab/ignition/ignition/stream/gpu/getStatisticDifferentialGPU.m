function [dstat, stat] = getStatisticDifferentialGPU(F, stat)
% GETSTATISTICDIFFERENTIALGPU
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
%			>> [dstat, stat] = getStatisticDifferentialGPU(F);
%			>> [dstat, stat] = getStatisticDifferentialGPU(F, stat);
%
% SEE ALSO:
%			COMPUTENONSTATIONARITYRUNGPUKERNEL, UPDATESTATISTICSGPU, IGNITION.STATISTICCOLLECTOR
%
% Mark Bucklin

% ============================================================
% GPU COMPANION FUNCTION UNIVERSAL HEADER
% ============================================================
persistent ...	
	numFrames ...
	rowSubs colSubs chanSubs frameSubs ...
	frameDim ...
	numPixels
if isempty(numPixels) || (numel(F) ~= numPixels) %, defineVideoFormat, end
	[~,~,~,numFrames] = getVideoSegmentSize(F);
	[rowSubs, colSubs, chanSubs, frameSubs] = getVideoSegmentSubscripts(F);
	[~, ~, ~, frameDim] = getVideoSegmentDimension();
	numPixels = numel(F);
end


if (nargin < 2)
	stat = [];
end
numSamples = single(numFrames);
k0 = int32(0);

if isInitialized()
	% ============================================================
	% RUN INCREMENTAL UPDATE KERNEL WITH GIVEN STATS
	% ============================================================
	
	% FROM 2ND INPUT ARGUMENT: PRESUMED OUTPUT OF PREVIOUS CALL	
	[N,Fmin,Fmax,M1,M2,M3,M4] = fromStatStruct();	
		
	% COMPUTE DIFFERENTIAL MOMENTS BALANCING ACCURACY AND SPEED	
	updateFineGrain = N < 32768;
	
	if updateFineGrain
		% CALL KERNEL TO COMPUTE TRUE INCREMENTAL UPDATE TO CENTRAL MOMENTS (more accurate at low sample-size)
		[dM1,dM2,dM3,dM4] = arrayfun(@sequentialDifferentialKernel, rowSubs, colSubs, chanSubs, frameSubs);
		
	else
		% CALL KERNEL TO COMPUTE CHUNKED INCREMENTAL UPDATE TO CENTRAL MOMENTS (faster)
		[dM1,dM2,dM3,dM4] = arrayfun(@chunkedParallelDifferentialKernel, F, M1, M2, M3);
		
	end
	
	
	
	% todo -> enable execution of independent functions (e.g. from global queue) here during the time
	% normally spent waiting for results to return. Implement 'lowPriorityTaskHeap' function with
	% persistent task_queue variable containing anonymous functions & estimated processing times. When
	% queue/heap is empty -> tic the entrance-time and return onCleanUp class that tocs and caches the
	% function finish time... better yet   ----->   every time the 'idle-volunteer' function is
	% called, tIn=tic the entrance, Cexit=oncleanup( @()cacheTimeSpent(borrowingTaskID,tIn))  ... and
	% also return --> Ccallerterm=onCleanup( @() cacheCallerTerminateTime(donatingTaskID,tIn)) --->
	% the onCleanup functions look like:
	%
	%			function cacheTimeSpent(id,t)
	%					tSpent=toc(t); 
	%					addToBorrowingTaskProfile(id,tSpent); 
	%
	% addTo__TaskProfile() caches last few samples in persistent hash-map, and records average in
	% separate donor/borrower task-performance profile defined at parent function level (or globally)
	
	
	
	% UPDATE CENTRAL MOMENTS FOR USE IN NEXT FRAME
	[Fmin,Fmax,M1,M2,M3,M4] = arrayfun(@statUpdateLoopInternalKernel,...
		Fmin,Fmax,M1,M2,M3,M4, N, rowSubs, colSubs, chanSubs);
	
	
	
	% todo -> enable execution of independent functions (e.g. from global queue) here during the time
	% normally spent waiting for results to return
	
	
	
else
	% ============================================================
	% INITIALIZE STATISTICS (MIN/MAX & CENTRAL MOMENTS)
	% ============================================================
	
	% ---------------------------------------
	% INITIALIZE & RETURN
	% ---------------------------------------	
	[N,Fmin,Fmax,M1,M2,M3,M4] = initializeStats();
	
	% 	N = gpuArray.zeros(1,'single');
	%
	% 	% MAX & MIN
	% 	Fmin = single(min(F,[],3));
	% 	Fmax = single(max(F,[],3));
	%
	% 	% MOMENTS MEASURED ON 1ST INPUT: PRESUMING 1ST CALL
	% 	Ffp = single(F);
	% 	M1 = single(mean(Ffp, 3));
	% 	M2 = single(moment(Ffp, 2, 3));
	% 	M3 = single(moment(Ffp, 3, 3));
	% 	M4 = single(moment(Ffp, 4, 3));
	% 	numSamples = single(numFrames);
	% 	%NEWend
	%
	% 	% 	N = gpuArray.ones(1,'single'); % 	N = single(0); % TODO: use 1, 0 or numFrames to smooth first input
	% 	% 	Fmin = single(min(F,[],3));
	% 	% 	Fmax = single(max(F,[],3));
	% 	%
	% 	% 	% MOMENTS MEASURED ON 1ST INPUT: PRESUMING 1ST CALL
	% 	% 	M1 = single(F(:,:,1,:));
	% 	% 	M2 = (single(F(:,:,1,:))-single(F(:,:,2,:))).^2;
	% 	% 	M3 = gpuArray.zeros(numRows,numCols,1,numChannels, 'single');
	% 	% 	M4 = gpuArray.zeros(numRows,numCols,1,numChannels, 'single');
	% 	% 	numSamples = single(numFrames) - 1; % NEW
	% 	% 	k0 = int32(1);
	%
	% 	% PRE-COMPUTE CENTRAL MOMENTS FOR FIRST CHUNK
	% 	% 	[fMin,fMax,fM1,fM2,fM3,fM4] = arrayfun(@statUpdateLoopInternalKernel,...
	% 	% 		fMin,fMax,fM1,fM2,fM3,fM4, N, rowSubs, colSubs, chanSubs);
	%
	% CALL KERNEL TO COMPUTE TRUE INCREMENTAL UPDATE TO CENTRAL MOMENTS
	[dM1,dM2,dM3,dM4] = arrayfun(@sequentialDifferentialKernel, rowSubs, colSubs, chanSubs, frameSubs);
	
	% UPDATE CENTRAL MOMENTS FOR USE IN NEXT FRAME (moved from above)
	% 	[Fmin,Fmax,M1,M2,M3,M4] = arrayfun(@statUpdateLoopInternalKernel,...
	% 		Fmin,Fmax,M1,M2,M3,M4, N, rowSubs, colSubs, chanSubs);
	
end



% ============================================================
% STORE OUTPUT IN STRUCTURES -> STAT & DSTAT
% ============================================================

% N UPDATE
stat.N = single(N) + numSamples;
stat.Min = Fmin;
stat.Max = Fmax;

% MOMENTS IN STRUCTURE OF STATIC STATISTICS --> (USED FOR NEXT INPUT)
stat.M1 = M1;
stat.M2 = M2;
stat.M3 = M3;
stat.M4 = M4;

% FILL DIFFERENTIAL-MOMENT (NON-STATIONARITY) STRUCTURE --> (OUTPUT)
dstat.M1 = dM1;
dstat.M2 = dM2;
dstat.M3 = dM3;
dstat.M4 = dM4;






% ##################################################
% SUB-FUNCTIONS
% ##################################################
	function init = isInitialized()
		init = ~isempty(stat) ...
			&& isstruct(stat) ...
			&& isfield(stat,'N') ...
			&& ~isempty(stat.N) ...
			&& (stat.N>0);
	end
	function [N,Fmin,Fmax,M1,M2,M3,M4] = fromStatStruct()
		N = single(stat.N);
		Fmin = single(stat.Min);
		Fmax = single(stat.Max);
		M1 = single(stat.M1);
		M2 = single(stat.M2);
		M3 = single(stat.M3);
		M4 = single(stat.M4);
	end
	function [N,Fmin,Fmax,M1,M2,M3,M4] = initializeStats()
		N = gpuArray.zeros(1,'single');
		
		% MAX & MIN
		Fmin = single(min(F,[],frameDim));
		Fmax = single(max(F,[],frameDim));
		
		% MOMENTS MEASURED ON 1ST INPUT: PRESUMING 1ST CALL
		Ffp = single(F);
		M1 = single(mean(Ffp, frameDim));
		M2 = single(moment(Ffp, 2, frameDim));
		M3 = single(moment(Ffp, 3, frameDim));
		M4 = single(moment(Ffp, 4, frameDim));
	end





% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################
	function [dm1,dm2,dm3,dm4] = sequentialDifferentialKernel(rowIdx, colIdx, chanIdx, frameIdx)
		
		% RETRIEVE PRIOR CENTRAL MOMENTS
		m1 = M1(rowIdx,colIdx,chanIdx,1);
		m2 = M2(rowIdx,colIdx,chanIdx,1);
		m3 = M3(rowIdx,colIdx,chanIdx,1);
		m4 = M4(rowIdx,colIdx,chanIdx,1);
		
		% INITIALIZE OUTPUT
		dm1 = single(0);
		dm2 = single(0);
		dm3 = single(0);
		dm4 = single(0);
				
		% LOOP THROUGH SEQUENTIAL FRAMES FOR 1-BY-1-UPDATE		
		k = int32(0);
		n = single(N);
		while k < frameIdx
			
			% UPDATE SAMPLE INDICES (USUALLY TEMPORAL)
			k = k + 1;
			n = n + 1; % n = single(na + k);
			
			% GET PIXEL SAMPLE			
			f = single(F(rowIdx,colIdx,chanIdx,k));
			
			% PRECOMPUTE & CACHE SOME VALUES FOR SPEED
			d = f - m1;
			dk = d/n;
			dk2 = dk^2;
			s = d*dk*(n-1);
			
			% COMPUTE DIFFERENTIAL UPDATE TO CENTRAL MOMENTS
			dm1 = dk;
			m1 = m1 + dm1;
			dm4 = s*dk2*(n^2-3*n+3) + 6*dk2*m2 - 4*dk*m3;
			m4 = m4 + dm4;
			dm3 = s*dk*(n-2) - 3*dk*m2;
			m3 = m3 + dm3;			
			dm2 = s;
			m2 = m2 + dm2;			
			
		end
		
		% NORMALIZE BY VARIANCE & SAMPLE NUMBER
		dm2 = dm2/max(1,n-1);
		dm3 = dm3*sqrt(max(1,n))/(m2^1.5);
		dm4 = dm4*n/(m2^2);
		% 		sqrtm2 = sqrt(m2);
		% 		sqrtn = sqrt(n);
		% 		dm2 = sqrt(dm2)/sqrtn;
		% 		dm3 = dm3*sqrtn/(sqrtm2^3);
		% 		dm4 = dm4*n/(sqrtm2^4);
		
	end
	
	function [dm1,dm2,dm3,dm4] = chunkedParallelDifferentialKernel(fin, m1, m2, m3)
		
		% RETRIEVE PRIOR CENTRAL MOMENTS
		n = single(N) + 1;
		f = single(fin);
		
		% PRECOMPUTE & CACHE SOME VALUES FOR SPEED
		d = f - m1;
		dk = d/n;
		dk2 = dk^2;
		s = d*dk*(n-1);
		
		% COMPUTE DIFFERENTIAL UPDATE TO CENTRAL MOMENTS
		dm1 = dk;
		% 		m1 = m1 + dm1;
		dm4 = s*dk2*(n^2-3*n+3) + 6*dk2*m2 - 4*dk*m3;		
		dm3 = s*dk*(n-2) - 3*dk*m2;
		dm2 = s;
		m2 = m2 + dm2;
		
		% NORMALIZE BY VARIANCE & SAMPLE NUMBER -> CONVERSION TO dVar, dSkew, dKurt		
		dm2 = dm2/max(1,n-1);
		dm3 = dm3*sqrt(max(1,n))/(m2^1.5);
		dm4 = dm4*n/(m2^2);
		
		
	end

	function [fmin,fmax,m1,m2,m3,m4] = statUpdateLoopInternalKernel(fmin,fmax,m1,m2,m3,m4,n,rowIdx,colIdx,chanIdx)

		% ---------------------------------------
		% LOOP THROUGH SEQUENTIAL FRAMES FOR 1-BY-1-UPDATE
		% ---------------------------------------
		% 		k = int32(0);
		k = k0;
		while k < numSamples
			
			% UPDATE SAMPLE INDICES (USUALLY TEMPORAL)
			k = k + 1;
			n = n + 1; % TODO: allow mask/conditional input
			
			% GET PIXEL SAMPLE
			f = single(F(rowIdx,colIdx,chanIdx,k));
						
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
			fmin = min(fmin, f);
			fmax = max(fmax, f);			
			
		end
		
	end









end










function stat = updateStatisticsGPU(F, stat)
% UPDATESTATISTICSGPU
% 
% USAGE:
%			>> stat = updateStatisticsGPU(F);
%			>> stat = updateStatisticsGPU(F, stat);
%
% SEE ALSO:
%			COMPUTENONSTATIONARITYRUNGPUKERNEL, GETSTATISTICDIFFERENTIALGPU IGNITION.STATISTICCOLLECTOR
%
% Mark Bucklin







% ============================================================
% INFO ABOUT INPUT
% ============================================================
[numRows,numCols,numFrames,numChannels] = size(F);
rowSubs = int32(gpuArray.colon(1,numRows)');
colSubs = int32(gpuArray.colon(1,numCols));
chanSubs =  int32(reshape(gpuArray.colon(1, numChannels), 1,1,1,numChannels));


% ============================================================
% RUN KERNEL TO UPDATE STAT INPUT OR INITIALIZE STATS & RETURN
% ============================================================
if (nargin < 2)
	stat = [];
end

if ~isempty(stat) && isstruct(stat) && isfield(stat,'N') && (stat.N>0)
	% ---------------------------------------
	% RUN UPDATE KERNEL
	% ---------------------------------------
	
	% FROM 2ND INPUT ARGUMENT: PRESUMED OUTPUT OF PREVIOUS CALL
	N = single(stat.N);
	Fmin = single(stat.Min);
	Fmax = single(stat.Max);
	M1 = single(stat.M1);
	M2 = single(stat.M2);
	M3 = single(stat.M3);
	M4 = single(stat.M4);
	
	% UPDATE CENTRAL MOMENTS
	if numFrames >= 1
		[Fmin,Fmax,M1,M2,M3,M4] = arrayfun(@statUpdateKernel,...
			Fmin,Fmax,M1,M2,M3,M4,N, rowSubs,colSubs,chanSubs);
	end
			
else	
	% ---------------------------------------
	% INITIALIZE & RETURN
	% ---------------------------------------	
	N = gpuArray.zeros(1,'single');
	
	% MAX & MIN
	Fmin = single(min(F,[],3));
	Fmax = single(max(F,[],3));
		
	% MOMENTS MEASURED ON 1ST INPUT: PRESUMING 1ST CALL
	Ffp = single(F);
	M1 = single(mean(Ffp, 3));
	M2 = single(moment(Ffp, 2, 3));
	M3 = single(moment(Ffp, 3, 3));
	M4 = single(moment(Ffp, 4, 3));
	
end


% ============================================================
% STORE OUTPUT IN STRUCTURE -> STAT 
% ============================================================

% N UPDATE
stat.N = single(N) + single(numFrames);
stat.Min = Fmin;
stat.Max = Fmax;

% MOMENTS IN STRUCTURE OF STATIC STATISTICS --> (USED FOR NEXT INPUT)
stat.M1 = M1;
stat.M2 = M2;
stat.M3 = M3;
stat.M4 = M4;













% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################

	function [fmin,fmax,m1,m2,m3,m4] = statUpdateKernel(fmin,fmax,m1,m2,m3,m4,n, rowIdx,colIdx,chanIdx)
				
		% ---------------------------------------
		% LOOP THROUGH SEQUENTIAL FRAMES FOR 1-BY-1-UPDATE
		% ---------------------------------------
		k = int32(0);
		while k < numFrames
			
			% UPDATE SAMPLE INDICES (USUALLY TEMPORAL)
			k = k + 1;
			n = n + 1; % TODO: allow mask/conditional input
			
			% GET PIXEL SAMPLE
			f = single(F(rowIdx,colIdx,k,chanIdx));
						
			% PRECOMPUTE & CACHE SOME VALUES FOR SPEED
			d = f - m1;
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












function stat = statisticCollectorUpdateStat(F, stat)
warning('statisticCollectorUpdateStat.m being called from scrap directory: Z:\Files\MATLAB\toolbox\ignition\scrap')
% statisticCollectorUpdateStat
%
% USAGE:
%			>> stat = statisticCollectorUpdateStat(F);
%			>> stat = statisticCollectorUpdateStat(F, stat);
%
% SEE ALSO:
%			COMPUTENONSTATIONARITYRUNGPUKERNEL, DIFFERENTIALMOMENTGENERATORRUNGPUKERNEL SCICADELIC.STATISTICCOLLECTOR
%
% Mark Bucklin



% ============================================================
% INFO ABOUT INPUT
% ============================================================
[numRows,numCols,numFrames] = size(F);
rowSubs = int32(gpuArray.colon(1,numRows)');
colSubs = int32(gpuArray.colon(1,numCols));

if (nargin < 2)
	stat = [];
end

if ~isempty(stat)
	% ============================================================
	% RUN KERNEL WITH GIVEN INITIALIZATION STATS
	% ============================================================
	
	% FROM 2ND INPUT ARGUMENT: PRESUMED OUTPUT OF PREVIOUS CALL
	N = single(stat.N);
	Fmin = cast(stat.Min, 'like', F);
	Fmax = cast(stat.Max, 'like', F);
	M1 = single(stat.M1);
	M2 = single(stat.M2);
	M3 = single(stat.M3);
	M4 = single(stat.M4);
	numSamples = single(numFrames);
	k0 = int32(0);

else
	% ============================================================
	% INITIALIZE STATISTICS (MIN/MAX & CENTRAL MOMENTS)
	% ============================================================

	% INITIALIZE MAX AND MIN
	N = gpuArray.zeros(1,'single');
	Fmin = min(F,[],3);
	Fmax = max(F,[],3);
	
	% MOMENTS MEASURED ON 1ST INPUT: PRESUMING 1ST CALL
	M1 = single(F(:,:,1,:));
	M2 = gpuArray.zeros(numRows,numCols,1, 'single');
	M3 = gpuArray.zeros(numRows,numCols,1, 'single');
	M4 = gpuArray.zeros(numRows,numCols,1, 'single');
	numSamples = single(numFrames);
	k0 = int32(0);
	
end


% UPDATE CENTRAL MOMENTS
if numSamples >= 1
	[Fmin,Fmax,M1,M2,M3,M4] = arrayfun(@statUpdateKernelFcn, rowSubs, colSubs);
end


% ============================================================
% STORE OUTPUT IN STRUCTURE -> STAT
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





% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################

	function [fmin,fmax,m1,m2,m3,m4] = statUpdateKernelFcn(rowC, colC)
		
		% INITIALIZE N
		n = single(N);
		
		% RETRIEVE MAX & MIN
		fmin = Fmin(rowC,colC);
		fmax = Fmax(rowC,colC);
		
		% RETRIEVE PRIOR CENTRAL MOMENTS
		m1 = M1(rowC,colC);
		m2 = M2(rowC,colC);
		m3 = M3(rowC,colC);
		m4 = M4(rowC,colC);
		
		
		% ---------------------------------------
		% LOOP THROUGH SEQUENTIAL FRAMES FOR 1-BY-1-UPDATE
		% ---------------------------------------
		k = k0;
		while k < numSamples
			
			% UPDATE SAMPLE INDICES (USUALLY TEMPORAL)
			k = k + 1;
			n = n + 1;
			
			% GET PIXEL SAMPLE
			f = F(rowC,colC,k);
			
			% PRECOMPUTE & CACHE SOME VALUES FOR SPEED
			d = single(f) - m1;
			dk = d/n;
			dk2 = dk^2;
			s = d*dk*(n-1);
			
			% UPDATE CENTRAL MOMENTS
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







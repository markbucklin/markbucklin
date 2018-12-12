function [F, F0, A, stat, dmstat] = temporallyAdaptiveTemporalFilterRunGpuKernel(F, F0, A0, stat, dmstat, N0Max)
% function [F, F0, A, N, M1, M2, M3, M4, DKmax] = temporallyAdaptiveTemporalFilterRunGpuKernel(F, F0, A, N, M1, M2, M3, M4, DKmax)
% temporallyAdaptiveTemporalFilterRunGpuKernel
%
%		Is actually both temporally and spatially adaptive. Named "temporally adaptive" to distinguish
%		from spatially adaptive, which applies a different pixel-to-pixel filtering coefficient based on
%		spatial information only.
%
% SEE ALSO:
%
%
% Mark Bucklin



% ============================================================
% INFO ABOUT INPUT
% ============================================================
[numRows,numCols,numFrames,numChannels] = size(F);
numPixels = numRows*numCols;
rowSubs = int32(gpuArray.colon(1,numRows)');
colSubs = int32(gpuArray.colon(1,numCols));
frameSubs = int32(reshape(gpuArray.colon(1, numFrames), 1,1,numFrames));
chanSubs =  int32(reshape(gpuArray.colon(1, numChannels), 1,1,1,numChannels));

% INPUT -> BUFFERED OUTPUT FROM PREVIOUS CALL
if nargin < 6
	N0Max = [];
	if nargin < 5
		dmstat = [];
		if nargin < 4
			stat = [];
			if nargin < 3
				A0 = [];
				if nargin < 2
					F0 = [];
				end
			end
		end
	end
end

% FILL DEFAULTS IF NOT GIVEN WITH INPUT
if isempty(N0Max)
	N0Max = single(100);
end
if isempty(A0)
	A0 = single(0);
end
if isempty(F0)
	filterOrder = single(min(2,size(F,3)));
else
	filterOrder = single(min(2, size(F0,3)));
end


% ============================================================
% 1ST CALL WITH EMPTY INPUT -> INITIALIZE
% ============================================================
if isempty(stat)
	N = gpuArray.zeros(1,'single') + single(numFrames);
	A = gpuArray.zeros(numRows,numCols,numFrames, 'single');
	Ffp = single(F);
	M1 = mean(Ffp, 3);
	M2 = moment(Ffp, 2, 3);
	M3 = moment(Ffp, 3, 3);
	M4 = moment(Ffp, 4, 3);
	% 	[~,~,~,dM4] = arrayfun(@sequentialDifferentialKernel, rowSubs, colSubs, frameSubs, chanSubs);
	dmstat.M1dm = gpuArray.zeros(numRows,numCols,1, 'single');%mean(dM4,3);
	dmstat.M2dm = gpuArray.zeros(numRows,numCols,1, 'single');%moment(dM4, 2, 3);
	dmstat.R1 = [];
	dmstat.R2 = [];
	F0 = F(:,:,(numFrames-filterOrder+1):end, :);
	stat.N = N;
	stat.M1 = M1;
	stat.M2 = M2;
	stat.M3 = M3;
	stat.M4 = M4;
	return
	
end



% ============================================================
% 2ND & SUBSEQUENT CALLS
% ============================================================

% EXTRACT STATS FROM STRUCTS RETURNED BY PRIOR CALLS
N = stat.N;
M1 = stat.M1;
M2 = stat.M2;
M3 = stat.M3;
M4 = stat.M4;
M1dm = dmstat.M1dm;
M2dm = dmstat.M2dm;
R1 = dmstat.R1;
R2 = dmstat.R2;

% OTHER DEFAULT PARAMETERS (todo)
numStdLowLim = single(1);
numStdHighLim = single(3);



% ============================================================
% RUN INCREMENTAL UPDATE KERNEL
% ============================================================

if N <= 1024
	% CALL KERNEL TO COMPUTE TRUE INCREMENTAL UPDATE TO CENTRAL MOMENTS
	[~,~,~,dM4] = arrayfun(@sequentialDifferentialKernel, rowSubs, colSubs, frameSubs, chanSubs);
	
else
	% CALL KERNEL TO COMPUTE CHUNKED INCREMENTAL UPDATE TO CENTRAL MOMENTS
	[~,~,~,dM4] = arrayfun(@chunkedParallelDifferentialKernel, F, M1, M2, M3);
	
end

% CALL SEPARATE REDUNDANT KERNEL TO COMPUTE NEW CENTRAL MOMENTS
[M1,M2,M3,M4] = arrayfun(@statUpdateKernel, M1,M2,M3,M4, N, rowSubs, colSubs, chanSubs);

% ACCUMULATE DIFFERENTIAL MOMENT STATS
DM = dM4;
[M1dm,M2dm] = arrayfun(@updateDiffMomentStatKernel, M1dm,M2dm, N, rowSubs, colSubs, chanSubs);




% ============================================================
% USE ACCUMULATED DIFFERENTIAL MOMENT STATS IF N >= 64
% ============================================================
if N > 63
	
	% ============================================================
	% NORMALIZE PIXEL VALUES USING GEMAN-MCCLURE FUNCTION
	% ============================================================	
	DM = arrayfun( @gemanMcClureNormalizationKernel, DM, M2dm, N+numFrames);
	DMsig = arrayfun( @filteredNormalizedSignificanceKernel, DM,  rowSubs, colSubs, frameSubs, chanSubs);
	
	% ============================================================
	% MEASURE FRAMEWIDE CHANGE IN DIFFERENTIAL MOMENT
	% ============================================================
	R = sum(sum(DMsig))./numPixels;	
	if isempty(R1)
		% INITIALIZE R -> MEAN PERCENTAGE OF PIXELS WITH SIGNIFICANT CHANGE
		R1 = mean(R(:));
		R2 = moment(R(:),2);		
		
	else
		% CALCULATE NON-EXCLUSIVE UPDATES TO R1 & R2 (MEAN & VARIANCE OF R)
		na = N(1);
		nb = numFrames;
		r1a = R1;
		r2a = R2;
		r1b = mean(double(R(:)));
		r2b = moment(double(R(:)),2);
		dr = r1b - r1a;
		R1 = r1a + dr.*(nb./(na+nb));
		R2 = r2a + r2b + (dr.^2).*(na.*nb./(na+nb));
		
		% CALCULATE EXCLUSIVE UPDATE FOR R1 & R2 WITH STABLE SAMPLES ONLY
		Rcut = R1 + sqrt(R2).*max(1,numStdLowLim);
		isStable = R(:)>Rcut;
		Rstable = R(isStable);
		if ~all(isStable)
			if any(isStable)
				nb = sum(isStable);
				r1b = mean(double(Rstable));
				r2b = moment(double(Rstable),2);
				dr = r1b - r1a;
				R1 = r1a + dr.*(nb./(na+nb));
				R2 = r2a + r2b + (dr.^2).*(na.*nb./(na+nb));
			else
				R1 = r1a;
				R2 = r2a;
			end
		end
	end
	
	
	
	% ============================================================
	% FRAMEWIDE CHANGE -> GLOBAL TEMPORAL SUPPRESSOR COEFFICIENT
	% ============================================================
	rLow = R1 + sqrt(R2).*numStdLowLim;
	rHigh = R1 + sqrt(R2).*numStdHighLim;
	C = min(1, max(0, R - rLow) ./ (rHigh-rLow));
	
	
	% ============================================================
	% APPLY TEMPORAL FILTER (IF N > 128) & BUFFER NEXT CALL
	% ============================================================
	
	if any(C(:)>0) || any(A0(:)>0)
		
		% UPDATE A
		A = arrayfun( @updateFilterCoefficientKernel, DM, C, A0);
		
		% APPLY TEMPORAL FILTER
		kFrame = 1;
		if filterOrder == 1
			% FIRST ORDER RECURSIVE FILTER
			Fkm1 = F0;
			while kFrame <= numFrames
				[F(:,:,kFrame,:), Fkm1] = arrayfun( @arFilterKernel1, F(:,:,kFrame,:), Fkm1, A(:,:,kFrame,:));
				kFrame = kFrame+1;
			end
			F0 = Fkm1;
			
		else
			% SECOND ORDER RECURSIVE FILTER
			Fkm1 = F0(:,:,2,:);
			Fkm2 = F0(:,:,1,:);
			while kFrame <= numFrames
				[F(:,:,kFrame,:), Fkm1, Fkm2] = arrayfun( @arFilterKernel2, F(:,:,kFrame,:), Fkm1, Fkm2, A(:,:,kFrame,:));
				kFrame = kFrame+1;
			end
			F0 = cat(3, Fkm2, Fkm1);
			
		end
		
	else
		%BUFFER NEXT CALL ONLY
		if filterOrder == 1
			F0 = F(:,:,end,:);
		else
			F0 = F(:,:,end-1:end,:);
		end
		A = gpuArray.zeros(numRows,numCols,numFrames, 'single');
		
	end
	
else
	A = gpuArray.zeros(numRows,numCols,numFrames, 'single');
	
end


% ============================================================
% OUTPUT
% ============================================================
F0 = F(:,:,(numFrames-filterOrder+1):end, :);
% nDM0 = nDM(:,:,end,:);

stat.N = N + single(numFrames);
stat.M1 = M1;
stat.M2 = M2;
stat.M3 = M3;
stat.M4 = M4;
dmstat.M1dm = M1dm;
dmstat.M2dm = M2dm;
dmstat.R1 = R1;
dmstat.R2 = R2;








% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################

% ============================================================
% CENTRAL MOMENT UPDATE ######################################
% ============================================================
	function [dm1,dm2,dm3,dm4] = sequentialDifferentialKernel(rowIdx, colIdx, frameIdx, chanIdx)
		
		% RETRIEVE PRIOR CENTRAL MOMENTS
		m1 = M1(rowIdx,colIdx,1,chanIdx);
		m2 = M2(rowIdx,colIdx,1,chanIdx);
		m3 = M3(rowIdx,colIdx,1,chanIdx);
		m4 = M4(rowIdx,colIdx,1,chanIdx);
		
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
			f = F(rowIdx,colIdx,k,chanIdx);
			
			% COMPUTE DIFFERENTIAL UPDATE TO CENTRAL MOMENTS
			d = single(f) - m1;
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

	function [dm1,dm2,dm3,dm4] = chunkedParallelDifferentialKernel(f, m1, m2, m3)
		
		% RETRIEVE PRIOR CENTRAL MOMENTS
		n = single(N) + 1;
		
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

	function [m1,m2,m3,m4] = statUpdateKernel(m1,m2,m3,m4,n,rowIdx,colIdx,chanIdx)
		k = int32(0);
		while k < numFrames
			
			% UPDATE SAMPLE INDICES (USUALLY TEMPORAL)
			k = k + 1;
			n = n + 1; % TODO: allow mask/conditional input
			
			% GET PIXEL SAMPLE
			f = F(rowIdx,colIdx,k,chanIdx);
			
			% PRECOMPUTE & CACHE SOME VALUES FOR SPEED
			d = single(f) - m1;
			dk = d/n;
			dk2 = dk^2;
			s = d*dk*(n-1);
			
			% UPDATE CENTRAL MOMENTS % TODO: check that order is ok... m1->m4->m3->m2
			m1 = m1 + dk;
			m4 = m4 + s*dk2*(n^2-3*n+3) + 6*dk2*m2 - 4*dk*m3;
			m3 = m3 + s*dk*(n-2) - 3*dk*m2;
			m2 = m2 + s;
			
		end
		
	end

	function [m1,m2] = updateDiffMomentStatKernel(m1,m2,n,rowIdx,colIdx,chanIdx)
		k = int32(0);
		while k < numFrames
			
			% UPDATE SAMPLE INDICES (USUALLY TEMPORAL)
			k = k + 1;
			n = n + 1; % TODO: allow mask/conditional input
			
			% GET PIXEL SAMPLE
			f = DM(rowIdx,colIdx,k,chanIdx);
			
			% PRECOMPUTE & CACHE SOME VALUES FOR SPEED
			d = single(f) - m1;
			dk = d/n;
			dk2 = dk^2;
			s = d*dk*(n-1);
			
			% UPDATE CENTRAL MOMENTS % TODO: check that order is ok... m1->m4->m3->m2
			m1 = m1 + dk;
			m2 = m2 + s;
			
		end
		
	end

	function fgm = gemanMcClureNormalizationKernel( f, m2, n)
		f2 = single(f)^2;
		s2 = m2 / (n-1);
		fgm = f2 / (f2 + s2);
		
	end

	function c = filteredNormalizedSignificanceKernel( p, rowIdx, colIdx, frameIdx, chanIdx)
		
		b1 = single(.1);
		b2 = single(.25);
		
		% CALCULATE SUBSCRIPTS FOR SURROUNDING (NEIGHBOR) PIXELS
		rowU = int32(max( 1, rowIdx-1));
		rowD = int32(min( numRows, rowIdx+1));
		colL = int32(max( 1, colIdx-1));
		colR = int32(min( numCols, colIdx+1));
		
		% RETRIEVE NEIGHBOR NORMALIZED DIFFERENTIAL MOMENT VALUES
		pU = single(DM(rowU, colIdx, frameIdx, chanIdx));
		pL = single(DM(rowIdx, colL, frameIdx, chanIdx));
		pR = single(DM(rowIdx, colR, frameIdx, chanIdx));
		pD = single(DM(rowD, colIdx, frameIdx, chanIdx));
		
		surrAboveLowLim = (single(pU>b1) + single(pR>b1) + single(pD>b1) + single(pL>b1)) >= 2;
		pAboveHighLim = single(p) > b2;
		c = pAboveHighLim & surrAboveLowLim;
		
	end

	function a = updateFilterCoefficientKernel( m, c, a0)
		
		if c>0
			n0 = m*c*N0Max;
			a = single(exp(-filterOrder/n0));
		else
			a = single(0);
		end
		a = max( a, a0);
		
	end

	function [ft, sft] = normalizedGradientKernel(f, rowIdx, colIdx, frameIdx, chanIdx)
		fk = single(f);
		if frameIdx >= 2
			f0 = single(Fgm(rowIdx,colIdx,frameIdx-1,chanIdx));
		else
			f0 = single(Fgm0(rowIdx,colIdx,1,chanIdx));
		end
		ft = fk - f0;
		sft = sign(ft) * single( max(abs(fk),abs(f0)) >= single(.05));
		
	end

% ============================================================
% FIRST-ORDER ################################################
% ============================================================
	function [yk, ykm1] = arFilterKernel1(xk, ykm1, a32)
		% Recursive  filter along third dimension (presumably time)
		
		a = double(a32);
		yk = (1-a)*xk + a*ykm1;
		ykm1 = yk;
		
	end

% ============================================================
% SECOND-ORDER ###############################################
% ============================================================
	function [yk, ykm1, ykm2] = arFilterKernel2(xk, ykm1, ykm2, a32)
		% Recursive  filter along third dimension (presumably time)
		
		a = double(a32);
		yk = (1-a)^2*xk + 2*a*ykm1 - a^2*ykm2;
		ykm2 = ykm1;
		ykm1 = yk;
		
	end






end




% ============================================================
% MEASURE PROPORTION OF INCREASING TO DECREASING PIXELS
% ============================================================
% 	[Fgmt, sFgmt] = arrayfun( @normalizedGradientKernel, Fgm, rowSubs, colSubs, frameSubs, chanSubs);
% 	R = sum(sum(sFgmt)) ./ sum(sum(abs(sFgmt)));



% if isempty(M1)	|| isempty(M2) || isempty(M3) || isempty(M4)
% 	M1 = gpuArray.zeros(numRows,numCols,1,numChannels,'single');
% 	M2 = gpuArray.zeros(numRows,numCols,1,numChannels,'single');
% 	M3 = gpuArray.zeros(numRows,numCols,1,numChannels,'single');
% 	M4 = gpuArray.zeros(numRows,numCols,1,numChannels,'single');
% end



% if nargin > 9
% 	DKmax = gpuArray.zeros(numRows, numCols, 1, numChannels, 'single');




% % ON FIRST CALL RETURN F AS F0
% if isempty(F0)
% 	F0 = F;
% 	A = gpuArray.zeros(numRows,numCols,numFrames, 'single');
% 	N = single(numFrames);
% 	Ffp = single(F);
% 	M1 = mean(Ffp, 3);
% 	M2 = moment(Ffp, 2, 3);
% 	M3 = moment(Ffp, 3, 3);
% 	M4 = moment(Ffp, 4, 3);
%
% 	[dM1,dM2,dM3,dM4] = arrayfun(@sequentialDifferentialKernel, rowSubs, colSubs, frameSubs, chanSubs);
% 	M1dm = M4;
% 	M2dm =
% 	return
% end
% M1 = mean(Ffp, 3);
% M2 = moment(Ffp, 2, 3);
% M3 = moment(Ffp, 3, 3);
% M4 = moment(Ffp, 4, 3);

% if isempty(M1) || isempty(M2) || isempty(M3) || isempty(M4)
% 	M1 = single(F(:,:,1,:));
% 	M2 = gpuArray.zeros(numRows, numCols, 1, numChannels, 'single');
% 	M3 = gpuArray.zeros(numRows, numCols, 1, numChannels, 'single');
% 	M4 = gpuArray.zeros(numRows, numCols, 1, numChannels, 'single');
% 	N = N + 1;
% end
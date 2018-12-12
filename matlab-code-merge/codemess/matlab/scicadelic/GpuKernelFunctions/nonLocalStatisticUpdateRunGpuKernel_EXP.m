function nlstat = nonLocalStatisticUpdateRunGpuKernel_EXP(F, nlstat, displacementRange, numDisplacements)
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

% VIDEO/IMAGE SUBSCRIPTS
[numRows,numCols,numFrames,numChannels] = size(F);
rowSubs = int32(gpuArray.colon(1,numRows)');
colSubs = int32(gpuArray.colon(1,numCols));
chanSubs =  int32(reshape(gpuArray.colon(1, numChannels), 1,1,1,numChannels));

% CHECK OPTIONAL INPUTS
if nargin < 4
	numDisplacements = [];
	if nargin < 3
		displacementRange = [];
		if nargin < 2
			nlstat = [];
		end
	end
end

% DEFAULT INPUT -> RADIAL RANGE IS 1/4-1/2 FRAME-WIDTH
if isempty(displacementRange)
	displacementRange = int32(floor( min(numRows,numCols) .* [.125 .25] ));
end
if isempty(numDisplacements)
	numDisplacements = 4;
end
numSamples = int32(numDisplacements * numFrames);

% RANDOM DISPLACEMENTS TO DEFINE NON LOCAL PIXELS
minOffset = displacementRange(1);
randomOffset = gpuArray.randi([-1 1] .* double(diff(displacementRange)),numDisplacements,2,'int32');
nonLocalOffset = sign(randomOffset).*minOffset + randomOffset;
rowShift = reshape(nonLocalOffset(:,1), 1,1,1,1,numDisplacements);
colShift = reshape(nonLocalOffset(:,2), 1,1,1,1,numDisplacements);




% ============================================================
% INITIALIZE IF NECESSARY OR EXTRACT STATS & RUN UPDATE KERNEL
% ============================================================
if isempty(nlstat)
	% ---------------------------------------
	%	INITIALIZE STATS AT FIRST OFFSET
	% ---------------------------------------	
	Fnl = circshift(F(:,:,1,:), [rowShift(1) colShift(1)]);
	
	N = gpuArray.ones(1,'single');
	fMin = Fnl;
	fMax = Fnl;
	fM1 = single(Fnl);
	fM2 = gpuArray.zeros(numRows,numCols,1,numChannels, 'single');
	fM3 = gpuArray.zeros(numRows,numCols,1,numChannels, 'single');
	fM4 = gpuArray.zeros(numRows,numCols,1,numChannels, 'single');
	
	k0 = int32(1);
	
else
	% ---------------------------------------
	% EXTRACT STATS FROM PREVIOUS CALLS
	% ---------------------------------------	
	
	N = single(nlstat.N);
	fMin = nlstat.Min;
	fMax = nlstat.Max;
	fM1 = single(nlstat.M1);
	fM2 = single(nlstat.M2);
	fM3 = single(nlstat.M3);
	fM4 = single(nlstat.M4);
	
	k0 = int32(0);
		
end




% ============================================================
% RUN UPDATE KERNEL
% ============================================================
if numFrames >= 1
	[fMin,fMax,fM1,fM2,fM3,fM4,N] = arrayfun( @shiftedStatKernelFcn,...
		fMin,fMax,fM1,fM2,fM3,fM4,N, rowSubs,colSubs,chanSubs);
end


	

% ============================================================
% STORE OUTPUT IN STRUCTURE -> STAT 
% ============================================================

% N UPDATE
nlstat.N = single(N);
nlstat.Min = fMin;
nlstat.Max = fMax;

% MOMENTS IN STRUCTURE OF STATIC STATISTICS --> (USED FOR NEXT INPUT)
nlstat.M1 = fM1;
nlstat.M2 = fM2;
nlstat.M3 = fM3;
nlstat.M4 = fM4;













% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################



	function [fmin,fmax,m1,m2,m3,m4,n] = shiftedStatKernelFcn(fmin,fmax,m1,m2,m3,m4,n, rowIdx0,colIdx0,chanIdx)
				
		
		
		% ---------------------------------------
		% LOOP THROUGH SEQUENTIAL FRAMES FOR 1-BY-1-UPDATE
		% ---------------------------------------
		kSample = k0;
		for kDisplacement = 1:numDisplacements
			drow = rowShift(kDisplacement);
			dcol = colShift(kDisplacement);
			rowIdx = mod(rowIdx0+drow-1,numRows)+1;
			colIdx = mod(colIdx0+dcol-1,numCols)+1;
			frameIdx = 0;
			
			while frameIdx < numFrames
				
				% UPDATE SAMPLE & FRAME INDICES & TOTAL FRAME COUNT
				kSample = kSample + 1;
				frameIdx = frameIdx + 1;				
				n = n + 1;
				
				% GET PIXEL SAMPLE
				f = F(rowIdx,colIdx,frameIdx,chanIdx);
				
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









end


% 	kShift = 1;
%
% 	% CIRCSHIFT ELEMENTS BY RANDOM NUMBER OF ROWS/COLS
% 	rowShift = nonLocalOffset(kShift,1);
% 	colShift = nonLocalOffset(kShift,2);
% 	Fnl = circshift(F, [rowShift colShift]);
%
% 	% MAX & MIN
% 	fMin = min(Fnl,[],3);
% 	fMax = max(Fnl,[],3);
%
% 	% MOMENTS MEASURED ON 1ST INPUT: PRESUMING 1ST CALL
% 	Ffp = single(Fnl);
% 	fM1 = single(mean(Ffp, 3));
% 	fM2 = single(moment(Ffp, 2, 3));
% 	fM3 = single(moment(Ffp, 3, 3));
% 	fM4 = single(moment(Ffp, 4, 3));
%
% 	% UPDATE N
% 	N = N + single(numFrames);










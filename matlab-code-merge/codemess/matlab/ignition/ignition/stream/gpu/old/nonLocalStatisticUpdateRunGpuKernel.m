function nlstat = nonLocalStatisticUpdateRunGpuKernel(F, nlstat, displacementRange, numDisplacements, edgeWidth)
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

% VIDEO/IMAGE SUBSCRIPTS
[numRows,numCols,numFrames,numChannels] = size(F);
rowSubs = int32(gpuArray.colon(1,numRows)');
colSubs = int32(gpuArray.colon(1,numCols));
chanSubs =  int32(reshape(gpuArray.colon(1, numChannels), 1,1,1,numChannels));

% CHECK OPTIONAL INPUTS
if nargin < 5
	edgeWidth = [];
	if nargin < 4
		numDisplacements = [];
		if nargin < 3
			displacementRange = [];
			if nargin < 2
				nlstat = [];
			end
		end
	end
end

% DEFAULT INPUT -> RADIAL RANGE IS 1/4-1/2 FRAME-WIDTH
if isempty(displacementRange)
	displacementRange = int32(floor( min(numRows,numCols) .* [1/32 1/2] ));
end
if isempty(numDisplacements)
	numDisplacements = numFrames;
end
if isempty(edgeWidth)
	edgeWidth = ceil(min(numRows,numCols)/64);
end
numSamples = int32(max(numDisplacements , numFrames));
Cy = ceil((numRows+1)/2);
Cx = ceil((numCols+1)/2);

% RANDOM DISPLACEMENTS TO DEFINE NON LOCAL PIXELS
minOffset = displacementRange(1);
randomOffset = gpuArray.randi([-1 1] .* double(diff(displacementRange)),numSamples,2,'int32');
nonLocalOffset = sign(randomOffset).*minOffset + randomOffset;
rowShift = nonLocalOffset(:,1);
colShift = nonLocalOffset(:,2);



% ============================================================
% INITIALIZE IF NECESSARY OR EXTRACT STATS & RUN UPDATE KERNEL
% ============================================================
if isempty(nlstat)
	% ---------------------------------------
	%	INITIALIZE STATS AT FIRST OFFSET
	% ---------------------------------------
	% 	Fnl = circshift(F(:,:,1,:), [rowShift(1) colShift(1)]);
	Fnl = F(:,:,1,:);
	
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
if numSamples >= 1
	[fMin,fMax,fM1,fM2,fM3,fM4,N] = arrayfun( @shiftedStatUpdateKernel,...
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



	function [fmin,fmax,m1,m2,m3,m4,n] = shiftedStatUpdateKernel(fmin,fmax,m1,m2,m3,m4,n, rowIdx,colIdx,chanIdx)
		
		% ---------------------------------------
		% INITIALIZE SAMPLE COUNT & ROW-COL IDX
		% ---------------------------------------
		kSample = k0;
		
		% VECTOR POINTING FROM CENTER OF IMAGE
		ry = Cy - rowIdx;
		rx = Cx - colIdx;
		
		% ---------------------------------------
		% LOOP THROUGH SEQUENTIAL FRAMES FOR 1-BY-1-UPDATE
		% ---------------------------------------
		while kSample < numSamples
			
			% UPDATE SAMPLE & FRAME INDICES & TOTAL FRAME COUNT
			kSample = kSample + 1;			
			kDisplacement = mod(kSample - 1, numDisplacements) + 1;
			sampleFrameIdx = mod(kSample - 1, numFrames) + 1;
			n = n + 1;
			
			% UPDATE ROW & COLUMN INDICES FROM RANDOMLY GENERATED ROW/COL-SHIFTS
			sampleRowIdx = mod(rowIdx + rowShift(kDisplacement) - (edgeWidth+1), numRows - 2*edgeWidth) + (edgeWidth+1);
			sampleColIdx = mod(colIdx + colShift(kDisplacement) - (edgeWidth+1), numCols - 2*edgeWidth) + (edgeWidth+1);
			
			
			% GET PIXEL SAMPLE
			f = F(sampleRowIdx,sampleColIdx,sampleFrameIdx,chanIdx);
			
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









%% INITIALIZE
if ~exist('proc','var')
	proc = initProc;
else
	proc = initProc(proc.tl);
end

proc.tf.AutoRegressiveCoefficients = .7;
proc.tf.AutoRegressiveOrder = 2;

TF0 = scicadelic.TemporalFilter;
tfn0 = 24 * 1;
TF0.AutoRegressiveCoefficients = exp(-1/tfn0);
TF0.AutoRegressiveOrder = 1;

nBurnInFrames = 512;

%%
% Fsample = getDataSample(proc.tl, nBurnInFrames);
% [numRows,numCols,~] = size(Fsample);
numRows = proc.tl.FrameSize(1);
numCols = proc.tl.FrameSize(2);
N = proc.tl.FileFrameIdx.last(end);

% nBurnInFrames = N;

%%
Fcpu(numRows,numCols,nBurnInFrames) = uint16(0);
Ftcpu(numRows,numCols,nBurnInFrames) = uint8(0);
Rcpu(numRows,numCols,nBurnInFrames) = int8(0);
dMotMag(nBurnInFrames,1) = single(0);
dm1(numRows,numCols,nBurnInFrames) = uint8(0);
dm2(numRows,numCols,nBurnInFrames) = uint8(0);
dm3(numRows,numCols,nBurnInFrames) = uint8(0);
dm4(numRows,numCols,nBurnInFrames) = uint8(0);

%% BURN IN
% [sdata, sinfo] = getDataSample(TL);
if proc.tl.isLocked
	reset(proc.tl)
	idx = 0;	
end


%%
while ~isempty(idx) && (idx(end) < nBurnInFrames)
	[F, mot, dstat, proc] = feedFrameChunk(proc);
	Fsmooth = gaussFiltFrameStack(F, 1);
	[R,Rmean,Rvar] = computeLayerFromRegionalComparisonRunGpuKernel(F, [], [], Fsmooth);
	Rsmooth = gaussFiltFrameStack(R, 1);
	idx = oncpu(proc.idx(proc.idx <=nBurnInFrames));
	F0 = step(TF0, F);
	Ft = single(F)-single(F0);
	
	Fcpu(:,:,idx) = gather(F);
	Ftcpu(:,:,idx) = gather(uint8(256*expnorm(Ft)));
	Rcpu(:,:,idx) = gather(int8(128*Rsmooth));
	dMotMag(idx) = gather(mot.dmag);
	dm1(:,:,idx) = gather(uint8(256*expnorm(dstat.M1)));
	dm2(:,:,idx) = gather(uint8(256*expnorm(realsqrt(dstat.M2))));
	dm3(:,:,idx) = gather(uint8(256*expnorm(sslog(dstat.M3))));
	dm4(:,:,idx) = gather(uint8(256*expnorm(sslog(dstat.M4))));
end

%% CATCH UP
peakMask = gpuArray(any(Rcpu>.375, 3));
[S, B, bStability] = computeBorderDistanceRunGpuKernel(R);
S0 = mean(S,3);
B0 = mean(B,3);

idx = 0;
while idx(end) < nBurnInFrames
	idx = idx(end) + (1:16);
	idx = idx(idx<=nBurnInFrames);
	F = gpuArray(Fcpu(:,:,idx));
	Fsmooth = gaussFiltFrameStack(F, 1.5);
	R = computeLayerFromRegionalComparisonRunGpuKernel(F, [], [], Fsmooth);
	
	[S, B, bStability] = computeBorderDistanceRunGpuKernel(R, S0, B0);
	S0 = mean(S,3);
	B0 = mean(B,3);
	bStableCount = sum(bStability,3);
	
	T = findLocalPeaksRunGpuKernel(S, peakMask);

	

end



%% RUN
[F, mot, dstat, proc] = feedFrameChunk(proc);
% Fsmooth = gaussFiltFrameStack(F, 3);
Fsmooth = gaussFiltFrameStack(F, 1.5);
R = computeLayerFromRegionalComparisonRunGpuKernel(F, [], [], Fsmooth);
% [R,Rmean,Rvar] = computeLayerFromRegionalComparisonRunGpuKernel(F, [], [], Fsmooth);
Rsmooth = gaussFiltFrameStack(R, 1.5);
peakMask = peakMask | any(Rsmooth>0, 3);


[S, B, bStability] = computeBorderDistanceRunGpuKernel(R); 
S0 = mean(S,3);
B0 = mean(B,3);
bStableCount = sum(bStability,3);

T = findLocalPeaksRunGpuKernel(S, peakMask);

% s = computeSurfaceCharacterRunGpuKernel(Fsmooth);
% peakiness = max(0, max(0,-s.H).* s.K);
% peakinessCutoff = median(peakiness(peakiness>0));
% peakiness = 1 - 1./(sqrt(1 + (peakiness.^2)./(peakinessCutoff^2)));
% T2 = findLocalPeaksRunGpuKernel(peakiness, peakMask);
% roundedPeakMask = min(peakiness,[],3)>0;
% T3 = findLocalPeaksRunGpuKernel(peakiness, roundedPeakMask);

% imcomposite(cat(3, max(0,mean(Fsmooth,3)), max(0,mean(R,3)), mean(log1p(abs(dstat.M4)),3)), mean(s.H<0&s.K>0,3)>.5, mean(B,3)>.1, mean(peakiness>.6,3)>.5)

% k12 = sqrt(s.k1.^2 + s.k2.^2);
% k1Norm = s.k1 ./ k12;
% k2Norm = s.k2 ./ k12;
% inclusionMask =  (s.H<0) & (s.K>0) & (R>0);

[k1,k2,w1] = structureTensorEigDecompRunGpuKernel(Rsmooth); % or Fsmooth
H = (k1+k2)/2;
K = k1.*k2;
inclusionMask =  (H<=0) & (K>=0) & (R>0 | Rsmooth>0);
[Sh, Bh, bhStability] = computeBorderDistanceRunGpuKernel(-H); % might as well change to be matrix
Th = findLocalPeaksRunGpuKernel(Sh, peakMask);

edgeishness = B~=0 & Bh~=0;

peakiness = max(0, (-min(0,H)) .* K);
peakinessCutoff = median(peakiness(peakiness>0));
peakiness = 1 - 1./(sqrt(1 + (peakiness.^2)./(peakinessCutoff^2)));
T2 = findLocalPeaksRunGpuKernel(peakiness, peakMask);
roundedPeakMask = min(peakiness,[],3)>0;
T3 = findLocalPeaksRunGpuKernel(peakiness, roundedPeakMask);
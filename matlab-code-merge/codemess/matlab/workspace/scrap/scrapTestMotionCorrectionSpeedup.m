warning('scrapTestMotionCorrectionSpeedup.m being called from scrap directory: Z:\Files\MATLAB\toolbox\ignition\scrap')
%% SETUP
if ~exist('TL','var')
	TL = scicadelic.TiffStackLoader;
	TL.FramesPerStep = 16;
	setup(TL)
else
	reset(TL)
end

MF = scicadelic.HybridMedianFilter;

CE = scicadelic.LocalContrastEnhancer;
% CE.UseInteractive = true;

MCold = scicadelic.RigidMotionCorrector;
MCold.CorrectionInfoOutputPort = false;
MCold.AlwaysAlignToMovingAverage = true;

MCnew = scicadelic.MotionCorrector;
obj = MCnew;



N = TL.NFrames;
numFrames = TL.FramesPerStep;
numSteps = ceil(N/numFrames);
m = 0;
idx = 0;

preMcCorr.mean(N,1) = gpuArray(0);
postMcCorr.mean(N,1) = gpuArray(0);
preMcCorr.recent(N,1) = gpuArray(0);
postMcCorr.recent(N,1) = gpuArray(0);
motcorrection.mean(N,2) = gpuArray(0);
motcorrection.recent(N,2) = gpuArray(0);
tocolumn = @(x) reshape(x, numel(x), 1);

%% LOOP
while idx(end) < N
	t = tic;
	m=m+1;
	
	% LOAD
	[F, idx] = TL.step();
	fRaw = F;
	fprintf('IDX: %d-%d ===\t',idx(1),idx(end));
	loadTime = toc(t);
	fprintf('Load: %3.3gms\t',1000*loadTime/numFrames); t=tic;
	% HYBRID MEDIAN FILTER ON GPU
	F = step(MF, F);
	% CONTRAST ENHANCEMENT
	F = step(CE, F);
	processTime = toc(t);
	fprintf('PreProc: %3.3gms\t',1000*processTime/numFrames);t=tic;
	
	
	% MOTION CORRECTION
	if m>1
		fixedMean = MCold.FixedMean;
		fixedRecent = MCold.FixedPrevious;
	else
		fixedMean = F(:,:,1);
		fixedRecent = F(:,:,1);
	end
	% 	preMcCorr.mean(idx) = tocolumn(frameCorrGpu(F, fixedMean));
	% 	preMcCorr.recent(idx) = tocolumn(frameCorrGpu(F, fixedRecent));
	
	Fold = step( MCold, F);
	processTime = toc(t);
	fprintf('MotionCorrection(OLD): %3.3gms\t',1000*processTime/numFrames);t=tic;
	
	Fnew = step( obj, F);
	processTime = toc(t);
	fprintf('MotionCorrection(NEW): %3.3gms\t',1000*processTime/numFrames);t=tic;
	
	% 	postMcCorr.mean(idx) = tocolumn(frameCorrGpu(F, fixedMean));
	% 	postMcCorr.recent(idx) = tocolumn(frameCorrGpu(F, fixedRecent));
	% 	motcorrection.mean(idx,:) = MCold.CorrectionToMovingAverage;
	% 	motcorrection.recent(idx,:) = MCold.CorrectionToPrecedingFrame;
	
	F = Fnew;
	
	
	
	
	
	% SAVE ALL INFO IN WORKSPACE
	if m==1
		motionInfoOld = repmat(MCold.CorrectionInfo, numSteps,1);
		motionInfoNew = repmat(MCnew.CorrectionInfo, numSteps,1);
	else
		motionInfoOld(m) = MCold.CorrectionInfo;
		motionInfoNew(m) = MCnew.CorrectionInfo;
	end
	processTime = toc(t);
	fprintf('GPU2CPU: %3.3gms\n',1000*processTime/numFrames);
	
end


motOld = unifyStructArray(motionInfoOld);
motNew = unifyStructArray(motionInfoNew);

release(TL)

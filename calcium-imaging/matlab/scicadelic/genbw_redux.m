%%

TL = scicadelic.TiffStackLoader;
TL.FramesPerStep = 16;
setup(TL)

% CE = scicadelic.LocalContrastEnhancer;
% CE.UseInteractive = true;

% MC = scicadelic.RigidMotionCorrector;
% MC.CorrectionInfoOutputPort = false;
% MC.AdjunctFrameInputPort = true;
% MC.AdjunctFrameOutputPort = true;

% NEW
MF = scicadelic.HybridMedianFilter;
CE = scicadelic.LocalContrastEnhancer;
MC = scicadelic.MotionCorrector;
SC = scicadelic.StatisticCollector;
TF = scicadelic.TemporalFilter;

CD = scicadelic.CellDetector;
CD.RecurrenceFilterNumFrames = 3;
% CD.UseInteractive = true;

RP = scicadelic.RegionPropagator;


%% DATA SAMPLE & TUNING
% [sdata, sinfo] = getDataSample(TL);
% release(TL);

%%
% tune(CE, sdata)

%%
% sdata = getProcessedTuningData(CE);
% tune(CD, sdata)

%%
% bw = getProcessedTuningData(CD);

%%
% imLoader = TL;
% imProcessor = {CE, MC, CD};

%% PREALLOCATE
N = TL.NumFrames;
dataType = TL.OutputDataType;
Fcpu = zeros([TL.FrameSize N], dataType);
lmCpu = zeros([TL.FrameSize N], 'uint16');
framesPerStep = TL.FramesPerStep;
numSteps = ceil(N/framesPerStep);


%%
reset(TL)
idx = 0;
m = 0;

%%
runTime = tic;
while idx(end) < N
	chunkTime = tic;
	m=m+1;
	[F, idx] = step(TL);
	F = step(MF,F);	
	F = step(CE, F);
	F = step(MC, F);
	step(SC,F);
	F = step(TF, F);
	
	lm = step(CD, F);
	% 	step(RP, oncpu(F), lmCpu, oncpu(idx));
	
	
	% 	step(vid, lmCpu(:,:,end))
	
	
	Fcpu(:,:,idx) = oncpu(F);
	lmCpu(:,:,idx) = oncpu(lm);	
	
	
	
	if m==1
		motionInfo = repmat(MC.CorrectionInfo, numSteps,1);
	else
		motionInfo(m) = MC.CorrectionInfo;
	end
	disp(toc(chunkTime)/framesPerStep)
end
mot = unifyStructArray(motionInfo);

obj = generatePropagatingRegions(lmCpu, Fcpu);

fprintf('Total Time: %03.5g s\n', toc(runTime));
% [obj, benchTime] = tryprop(lmData);

release(TL)







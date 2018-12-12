%%

TL = scicadelic.TiffStackLoader;
setup(TL)
CE = scicadelic.LocalContrastEnhancer;
% CE.UseInteractive = true;

MC = scicadelic.RigidMotionCorrector;
MC.CorrectionInfoOutputPort = false;
MC.AdjunctFrameInputPort = true;
MC.AdjunctFrameOutputPort = true;

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
% N = TL.NFrames;
N = TL.NumFrames;
dataType = TL.OutputDataType;
% rawData = zeros([TL.FrameSize N], dataType);
ceData = zeros([TL.FrameSize N], dataType);
lmData = zeros([TL.FrameSize N], 'uint16');
framesPerStep = TL.FramesPerStep;
numSteps = ceil(N/framesPerStep);


%%
reset(TL)
idx = 0;
m = 0;

while idx(end) < N
	tic
	m=m+1;
	[data, idx] = TL.step();
	% 	rawData(:,:,idx) = oncpu(data);
	gRawData = data;
	data = step(CE, data);
	[data, gRawData] = step( MC, data, gRawData);
	ceData(:,:,idx) = oncpu(data);
	
	rawData = oncpu(gRawData);
% 	rawData(:,:,idx) = oncpu(gRawData);
	lm = step(CD, data);
	lmCpu = oncpu(lm);
	% 	step(vid, lmCpu(:,:,end))
	lmData(:,:,idx) = lmCpu;
	
	step(RP, rawData, lmCpu, oncpu(idx));
	
	
	if m==1
		motionInfo = repmat(MC.CorrectionInfo, numSteps,1);
	else
		motionInfo(m) = MC.CorrectionInfo;
	end
	disp(toc/framesPerStep)
end
mot = unifyStructArray(motionInfo);


release(TL)







%%
vid = vision.VideoPlayer;
if ~exist('TL','var')
	TL = rtsci.TiffStackLoader;
	TL.FramesPerStep = 16;
	setup(TL)
else
	reset(TL)
end
MF = rtsci.HybridMedianFilter;
CE = rtsci.LocalContrastEnhancer;
% CE.UseInteractive = true;

% MC = rtsci.RigidMotionCorrector;
MC = rtsci.MotionCorrector;
preSC = rtsci.StatisticCollector;
postSC = rtsci.StatisticCollector;

% CD = rtsci.CellDetector;
% CD.UseInteractive = true;


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
N = 512;
dataType = TL.OutputDataType;
premcData = zeros([TL.FrameSize N], dataType);
postmcData = zeros([TL.FrameSize N], dataType);
% lmData = zeros([TL.FrameSize N], 'uint16');
numSteps = ceil(N/TL.FramesPerStep);


%%
% release(TL)
% release(MC)

%%
idx = 0;
m = 0;

%%
while idx(end) < N
	m=m+1;
	[F, idx] = TL.step();
	F = step(MF, F);
	F = step(CE, F);
	
	step(preSC, F);
	premc = oncpu(F);
	F = step( MC, F);
	step(postSC, F);
	postmc = oncpu(F);
	premcData(:,:,idx) = premc;
	postmcData(:,:,idx) = postmc;
	
	% 	step(vid, cat(2, premc, postmc))
	% 	lm = step(CD, data);
	% 	lmCpu = oncpu(lm);
	% 	step(vid, lmCpu(:,:,end))
	% 	lmData(:,:,idx) = lmCpu;
	if m==1
		motionInfo = repmat(MC.CorrectionInfo, numSteps,1);
	else
		motionInfo(m) = MC.CorrectionInfo;
	end
	
	preMean = gather(single(preSC.Mean));
	postMean = gather(single(postSC.Mean));
	for k=1:numel(idx)
		step(vid, cat(2, single(premc(:,:,k))-preMean, single(postmc(:,:,k))-postMean))
		pause(.020)
	end
	
end
mot = unifyStructArray(motionInfo);

release(TL)



%% RANDOM CONTROLLED MOTION
N = 128;
n = 16;
M = ceil(N/n);
m=0;
idx = 0;
f = gather(uint16(F(:,:,1)));
fillVal = mean(mean([f(:,1) ; f(:,end)]));

premcRandData = zeros([TL.FrameSize N], dataType);
postmcRandData = zeros([TL.FrameSize N], dataType);
randMotionInfo(M) = motionInfo(1);

rx = exp(randn(N,1)) - exp(randn(N,1));
ry = exp(randn(N,1)) - exp(randn(N,1));

% MC = rtsci.RigidMotionCorrector;
% MCnew = MC;
% MC = MCold;

%%
m=0;
idx = 0;
MC2 = rtsci.MotionCorrector;
fTransInit = imtranslate(single(f), [rx(1) ry(1)], 'OutputView', 'same', 'FillValues', single(fillVal));

%%
while idx(end) < N
	idx = idx(end) + (1:n);
	idx = idx(idx<=N);
	m=m+1;
	for k=1:numel(idx)
		xyTrans = [rx(idx(k)) ry(idx(k))];
		fTransFp(:,:,k) = imtranslate(single(f), xyTrans, 'OutputView', 'same', 'FillValues', single(fillVal));
	end
	premc = uint16(fTransFp);
	postmc = gather(step( MC2, gpuArray(uint16(premc))));
	% 	postmc = gather(uint16(step( MC2, gpuArray(uint16(premc)))));
	info = MC2.CorrectionInfo;
	disp([bsxfun(@plus, -rx(idx),rx(1)) info.ux  bsxfun(@plus,-ry(idx),ry(1)) info.uy])
	
	premcRandData(:,:,idx) = premc;
	postmcRandData(:,:,idx) = postmc;
	randMotionInfo(m) = info;
	
	
	
	for k=1:numel(idx)
		step(vid, cat(2, single(premc(:,:,k))-fTransInit, single(postmc(:,:,k))-fTransInit))
		pause(.025)
	end
end


rmot = unifyStructArray(randMotionInfo);


plot([-(rx-rx(1)) rmot.ux  25-(ry-ry(1))  25+rmot.uy])
figure
histogram(rmot.ux + (rx-rx(1))), hold on, histogram(rmot.uy + (ry-ry(1)))
hold off

%%
m=0;
idx = 0;
fTransInit = imtranslate(single(f), [rx(1) ry(1)], 'OutputView', 'same', 'FillValues', single(fillVal));

fixedLocalInput = gpuArray(uint16(fTransInit(:,:,1)));
clear randMotionInfo

%%
while idx(end) < N
	idx = idx(end) + (1:n);
	idx = idx(idx<=N);
	m=m+1;
	for k=1:numel(idx)
		xyTrans = [rx(idx(k)) ry(idx(k))];
		fTransFp(:,:,k) = imtranslate(single(f), xyTrans, 'OutputView', 'same', 'FillValues', single(fillVal));
	end
	premc = uint16(fTransFp);
	
	[postmcgpu, Uxy] = correctMotionGpu(gpuArray(premc), fixedLocalInput, [], 10);
info.ux = single(gather(Uxy(:,2)));
info.uy = single(gather(Uxy(:,1)));
fixedLocalInput = postmcgpu(:,:,end);
	
% [postmcgpu, info] = step(MC, gpuArray(premc));
% MC.CorrectionToMovingAverage
	


	postmc = gather(postmcgpu);
	
	% 	postmc = gather(uint16(step( MC2, gpuArray(uint16(premc)))));
	% 	info = MC2.CorrectionInfo;
	
	
	
% 	fixedLocalInput = postmc(:,:,end);
	
% 	disp([bsxfun(@plus, -rx(idx),rx(1)) info.ux  bsxfun(@plus,-ry(idx),ry(1)) info.uy])
	
	premcRandData(:,:,idx) = gather(premc);
	postmcRandData(:,:,idx) = gather(postmc);
	randMotionInfo(m) = info;
	
	
	
	% 	for k=1:numel(idx)
	% 		step(vid, cat(2, single(premc(:,:,k))-fTransInit, single(postmc(:,:,k))-fTransInit))
	% 		pause(.025)
	% 	end
end


rmot = unifyStructArray(randMotionInfo);


% plot([-(rx-rx(1)) rmot.ux  25-(ry-ry(1))  25+rmot.uy])

figure
subplot(2,1,1)
histogram(double(rmot.ux) + double((rx-rx(1))), -2:.1:2)
hold on
histogram(double(rmot.uy) + double((ry-ry(1))), -2:.1:2)
hold off

ux = double(rmot.ux) + double((rx-rx(1)));
uy = double(rmot.uy) + double((ry-ry(1)));
ux0 = rx-rx(1);
uy0 = ry-ry(1);
subplot(2,1,2)
scatter(ux0-fix(ux0), ux, '.'); hold on; scatter(uy0-fix(uy0), uy, '.'); hold off
grid on
ylim([-1 1])


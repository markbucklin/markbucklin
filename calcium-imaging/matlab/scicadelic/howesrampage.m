

%%
waitfor(msgbox('Load TD-Mask'));
procTD = initProc;
Ntd = procTD.tl.NumFrames;

%%
idx = 0;
RtdSC = scicadelic.StatisticCollector;
Ftd(1024,1024,Ntd) = uint16(0);
Rcpu(1024,1024,Ntd) = single(0);

%%
while ~isempty(idx) && (idx(end) < Ntd)
	[F, mot, dstat, procTD] = feedFrameChunk(procTD);
	Fsmooth = gaussFiltFrameStack(F, 1);
	[R,Rmean,Rvar] = computeLayerFromRegionalComparisonRunGpuKernel(F, [], [], Fsmooth);
	step(RtdSC, R);
	Rsmooth = gaussFiltFrameStack(R, 1);
	idx = oncpu(procTD.idx(procTD.idx <=Ntd));
	Ftd(:,:,idx) = gather(F);
	Rtd(:,:,idx) = gather(Rsmooth);
end
% tdMask = gather(11/10*(max(.1, RtdSC.Mean)-.1));
a = .1; 
tdMask = gather(1/(1-a)*(max(a, RtdSC.Max)-a));

%% INITIALIZE
if ~exist('procGC','var')
	procGC = initProc;
else
	procGC = initProc(procGC.tl);
end
Ngc = procGC.tl.NumFrames;

nBurnInFrames = 512;
dMotMag(Ngc,1) = single(0);


%% BURN IN
for m=1:10
	[F, mot, dstat, procGC] = feedFrameChunk(procGC);
end
if procGC.tl.isLocked
	reset(procGC.tl)
end
idx = 0;
Fmean = gather(stackMean(F));

%%
fps = 24;
sz = size(F);
[filename, filedir] = uiputfile('*.mp4');
filename = fullfile(filedir,filename);
profile = 'MPEG-4';
writerObj = VideoWriter(filename,profile);
writerObj.FrameRate = fps;
writerObj.Quality = 90;
open(writerObj)


%%
h.fig = figure;
h.ax = axes('Parent',h.fig, 'Visible','off');
setpixelposition(h.ax,[100 100 1024 1024])
meanIm = imagesc('Parent',h.ax,'CData',Fmean);
gcim = image('Parent',h.ax,'CData',repmat(reshape([0 .6 .1],1, 1, 3),1024,1024,1), 'AlphaData'  ,gather(stackMean(dstat.M1).*(1-tdMask)));
tdim = image('Parent',h.ax,'CData',repmat(reshape([1 0 0],1, 1, 3),1024,1024,1), 'AlphaData'  ,gather(stackMean(dstat.M1).*tdMask));


%%
while ~isempty(idx) && (idx(end) < Ngc)
	[F, mot, dstat, procGC] = feedFrameChunk(procGC);
	Fsmooth = gaussFiltFrameStack(F, 1);
	R = computeLayerFromRegionalComparisonRunGpuKernel(F, [], [], Fsmooth);
	Rsmooth = gaussFiltFrameStack(R, 1);
	idx = oncpu(procGC.idx(procGC.idx <=Ngc));	
	dMotMag(idx) = gather(mot.dmag);
	dm1 = gather(dstat.M1);
	dm2 = gather(realsqrt(dstat.M2));
	dm3 = gather(sslog(dstat.M3));
	dm4 = gather(sslog(dstat.M4));	
	Fmean = gather(procGC.sc.Mean);
	Fmin = gather(procGC.sc.Min);
	Fstd = gather(procGC.sc.StandardDeviation);
	Fvar = gather(procGC.sc.Variance);
	
	gcActivity = gather(dm1);
	if ~exist('gcActivityMax','var')
		% 		gcActivityMax = stackMax(abs(gcActivity));
		gcActivityMax = stackMax(gcActivity);
	else
		gcActivityMax = (9*gcActivityMax  + stackMax(gcActivity))/10;
	end
	Fcpu = gather(Fsmooth);
	for k=1:size(gcActivity,3)
		gcChannel = pos(single(gcActivity(:,:,k)).*(1-tdMask)./single(gcActivityMax) - .7);
		tdChannel = single(gcActivity(:,:,k)).*tdMask./single(gcActivityMax);
		gcim.AlphaData = gcChannel;
		tdim.AlphaData = tdChannel;
		meanIm.CData = Fcpu(:,:,k).^2 ./ (1 + Fcpu(:,:,k).^2 ./ (2*single(Fvar)));
		drawnow
		im = getframe(h.ax);
% 		writeVideo(writerObj, im.cdata)
				pause(.05),
	end
	
end
close(writerObj);

%% CATCH UP



%% RUN
[F, mot, dstat, procGC] = feedFrameChunk(procGC);
% Fsmooth = gaussFiltFrameStack(F, 3);
Fsmooth = gaussFiltFrameStack(F, 1.5);
R = computeLayerFromRegionalComparisonRunGpuKernel(F, [], [], Fsmooth);
% [R,Rmean,Rvar] = computeLayerFromRegionalComparisonRunGpuKernel(F, [], [], Fsmooth);
Rsmooth = gaussFiltFrameStack(R, 1.5);
peakMask = any(Rsmooth>0, 3);


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
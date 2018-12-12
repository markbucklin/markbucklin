% 
% 
% %%
% waitfor(msgbox('Load Control'));
% procControl = initProc;
% Ncontrol = procControl.tl.NumFrames;
% 
% %%
% idx = 0;
% RcontrolSC = scicadelic.StatisticCollector;
% Fcontrol(1024,1024,Ncontrol) = uint16(0);
% Rcontrol(1024,1024,Ncontrol) = single(0);
% 
% %%
% while ~isempty(idx) && (idx(end) < Ncontrol)
% 	[Fcontrol, mot, dstat, procControl] = feedFrameChunk(procControl);
% 	Fsmooth = gaussFiltFrameStack(Fcontrol, 1);
% 	[Rcontrol,Rmean,Rvar] = computeLayerFromRegionalComparisonRunGpuKernel(Fcontrol, [], [], Fsmooth);
% 	step(RcontrolSC, Rcontrol);
% 	Rsmooth = gaussFiltFrameStack(Rcontrol, 1);
% 	idx = oncpu(procControl.idx(procControl.idx <=Ncontrol));
% 	Fcontrol(:,:,idx) = gather(Fcontrol);
% 	Rcontrol(:,:,idx) = gather(Rsmooth);
% end
% % tdMask = gather(11/10*(max(.1, RtdSC.Mean)-.1));
% a = .1; 
% controlMask = gather(1/(1-a)*(max(a, RcontrolSC.Max)-a));
% 
% 
% 



waitfor(msgbox('Load glut'));


TL = scicadelic.TiffStackLoader;
TL.FramesPerStep = 1;
setup(TL)
MF = scicadelic.HybridMedianFilter;
CE = scicadelic.LocalContrastEnhancer;
SC = scicadelic.StatisticCollector;
SC.DifferentialMomentOutputPort = true;


procGlut.tl = TL;
procGlut.mf = MF;
procGlut.ce = CE;
% procGlut.mc = MC;
procGlut.sc = SC;
procGlut.idx = 0;
procGlut.m = 0;
procGlu.mc = scicadelic.MotionCorrector;

[Fglut, idx] = procGlut.tl.step();
% F = hybridMedianFilterRunGpuKernel(F);
Fglut = step(procGlut.ce, Fglut);
dstat = step(procGlut.sc, Fglut);
procGlut.idx = 0;
procGlut.m = 0;




%%

% procGlut.tl.FramesPerStep = 8;
Nglut = procGlut.tl.NumFrames;

%%
idx = 0;
RglutSC = scicadelic.StatisticCollector;
Fcpu(1024,1024,Nglut) = uint16(0);
Rcpu(1024,1024,Nglut) = single(0);
dm1(1024,1024,Nglut) = single(0);
dm2(1024,1024,Nglut) = single(0);
dm3(1024,1024,Nglut) = single(0);
dm4(1024,1024,Nglut) = single(0);

%%
% while ~isempty(idx) && (idx(end) < Nglut)
	
	% 	[Fglut, mot, dstat, procGlut] = feedFrameChunk(procGlut);
	[Fglut, idx] = procGlut.tl.step();
	try
		Fglut = step(procGlut.mf, Fglut);
	catch
		disp('mf fail')
		Fglut =  hybridMedianFilterRunGpuKernel(Fglut);
	end
	Fglut = step(procGlut.ce, Fglut);
	dstat = step(procGlut.sc, Fglut);
	
	
	
	Fsmooth = gaussFiltFrameStack(Fglut, 1);
	[Rglut,Rmean,Rvar] = computeLayerFromRegionalComparisonRunGpuKernel(Fglut, [], [], Fsmooth);
	step(RglutSC, Rglut);
	Rsmooth = gaussFiltFrameStack(Rglut, 1);
	% 	Rsmooth = gaussFiltFrameStack(Rglut(:,:,1:32:(32*10)), 1);
	idx = oncpu(idx(idx <=Nglut));
	Fcpu(:,:,idx) = gather(Fglut);
	Rcpu(:,:,idx) = gather(Rsmooth);

	% end
% tdMask = gather(11/10*(max(.1, RtdSC.Mean)-.1));
a = .1; 

% glutMask = gather(1/(1-a)*(max(a, RglutSC.Max)-a));


controlMask = stackMean(Rsmooth) > .4;



%% INITIALIZE
% if ~exist('procGC','var')
% 	procGlut = initProc;
% else
% 	procGlut = initProc(procGlut.tl);
% end
% procGC.tl.FramesPerStep = 8;

Nglut = 600; %procGlut.tl.NumFrames; % WHOOOOOOAAA!!!! WATCH OUT!!!
% 
% nBurnInFrames = 600;
% dMotMag(Nglut,1) = single(0);
% 
% 
% %% BURN IN
% for m=1:10
% 	[Fglut, mot, dstat, procGlut] = feedFrameChunk(procGlut);
% end
if procGlut.tl.isLocked
	reset(procGlut.tl)
end
idx = 0;
Fmean = gather(stackMean(Fglut));

%%
% fps = 24;
% sz = size(Fglut);
% [filename, filedir] = uiputfile('*.mp4');
% filename = fullfile(filedir,filename);
% profile = 'MPEG-4';
% writerObj = VideoWriter(filename,profile);
% writerObj.FrameRate = fps;
% writerObj.Quality = 90;
% open(writerObj)


% %%
% h.fig = figure;
% h.ax = axes('Parent',h.fig, 'Visible','off');
% setpixelposition(h.ax,[100 100 1024 1024])
% meanIm = imagesc('Parent',h.ax,'CData',Fmean);
% colormap gray
% gcim = image('Parent',h.ax,'CData',repmat(reshape([0 .6 .1],1, 1, 3),1024,1024,1), 'AlphaData'  ,gather(stackMean(dstat.M1).*(1-controlMask)));
% tdim = image('Parent',h.ax,'CData',repmat(reshape([1 0 0],1, 1, 3),1024,1024,1), 'AlphaData'  ,gather(stackMean(dstat.M1).*controlMask));


%%
while ~isempty(idx) && (idx(end) < Nglut)
	
	
	
	[Fglut, idx] = procGlut.tl.step();	
	try
		Fglut = step(procGlut.mf, Fglut);
	catch
		disp('mf fail')
		Fglut =  hybridMedianFilterRunGpuKernel(Fglut);
	end
	Fglut = step(procGlut.ce, Fglut);
	dstat = step(procGlut.sc, Fglut);
		
	
	% 	[Fglut, mot, dstat, procGlut] = feedFrameChunk(procGlut);
	Fsmooth = gaussFiltFrameStack(Fglut, 1);
	Rglut = computeLayerFromRegionalComparisonRunGpuKernel(Fglut, [], [], Fsmooth);
	Rsmooth = gaussFiltFrameStack(Rglut, 1);
	idx = oncpu(idx(idx <=Nglut));	
	% 	dMotMag(idx) = gather(mot.dmag);
	Fcpu(:,:,idx) = gather(Fglut);
	Rcpu(:,:,idx) = gather(Rsmooth);
	dm1(:,:,idx) = gather(dstat.M1);
	dm2(:,:,idx) = gather(realsqrt(dstat.M2));
	dm3(:,:,idx) = gather(sslog(dstat.M3));
	dm4(:,:,idx) = gather(sslog(dstat.M4));	
	
end
% 	Fmean = gather(procGlut.sc.Mean);
% 	Fmin = gather(procGlut.sc.Min);
% 	Fstd = gather(procGlut.sc.StandardDeviation);
% 	Fvar = gather(procGlut.sc.Variance);
% 	
% 	gcActivity = gather(dm1);
% 	if ~exist('gcActivityMax','var')
% 		% 		gcActivityMax = stackMax(abs(gcActivity));
% 		gcActivityMax = stackMax(gcActivity);
% 	else
% 		gcActivityMax = (9*gcActivityMax  + stackMax(gcActivity))/10;
% 	end
% 	Fcpu = gather(Fsmooth);
% 	for k=1:size(gcActivity,3)
% 		gcChannel = pos(single(gcActivity(:,:,k)).*(1-controlMask)./single(gcActivityMax) - .7);
% 		tdChannel = single(gcActivity(:,:,k)).*controlMask./single(gcActivityMax);
% 		gcim.AlphaData = gather(gcChannel);
% 		tdim.AlphaData = gather(tdChannel);
% 		meanIm.CData = Fcpu(:,:,k).^2 ./ (1 + Fcpu(:,:,k).^2 ./ (2*single(Fvar)));
% 		drawnow
% 		im = getframe(h.ax);
% 		writeVideo(writerObj, im.cdata)
% 				
% 	end
	
% end

%%


%% CATCH UP



%% RUN
[Fglut, mot, dstat, procGlut] = feedFrameChunk(procGlut);
% Fsmooth = gaussFiltFrameStack(F, 3);
Fsmooth = gaussFiltFrameStack(Fglut, 1.5);
Rglut = computeLayerFromRegionalComparisonRunGpuKernel(Fglut, [], [], Fsmooth);
% [R,Rmean,Rvar] = computeLayerFromRegionalComparisonRunGpuKernel(F, [], [], Fsmooth);
Rsmooth = gaussFiltFrameStack(Rglut, 1.5);
peakMask = any(Fsmooth>0, 3);


[S, B, bStability] = computeBorderDistanceRunGpuKernel(Rglut); 
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
inclusionMask =  (H<=0) & (K>=0) & (Rglut>0 | Rsmooth>0);
[Sh, Bh, bhStability] = computeBorderDistanceRunGpuKernel(-H); % might as well change to be matrix
Th = findLocalPeaksRunGpuKernel(Sh, peakMask);

edgeishness = B~=0 & Bh~=0;

peakiness = max(0, (-min(0,H)) .* K);
peakinessCutoff = median(peakiness(peakiness>0));
peakiness = 1 - 1./(sqrt(1 + (peakiness.^2)./(peakinessCutoff^2)));
T2 = findLocalPeaksRunGpuKernel(peakiness, peakMask);
roundedPeakMask = min(peakiness,[],3)>0;
T3 = findLocalPeaksRunGpuKernel(peakiness, roundedPeakMask);
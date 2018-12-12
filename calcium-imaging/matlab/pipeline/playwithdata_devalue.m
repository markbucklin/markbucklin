%% INLINE FUNCTIONS
normZ = @(v) bsxfun(@rdivide, bsxfun(@minus, v, mean(v,1)), std(v,[],1));
norm01 = @(v) bsxfun(@rdivide, bsxfun(@minus, v, min(v,[],1)), range(v,1));
normlt1 = @(v) bsxfun(@rdivide, bsxfun(@minus, v, mean(v,1)), max(abs(v),[],1));

%% FOLDER FOR SAVING FIGURES
figDir = [pwd,filesep,'Figures'];
if ~isdir(figDir)
   mkdir(figDir)
end

%% LOAD ROI DATA (R)
d = dir('*_ROIwithTraces*');
load(d(1).name);
nRoi = numel(R);

% DETREND FLUORESCENCE SIGNAL
f = single([R.Trace]);
fPreFilter = f;
f = detrend(f, 'linear');

%% LOWPASS FILTER
% [pxx,pfreq] = pcov(f, 21,[],20);
% plot(pfreq,log(pxx),'.'), hold on, plot(pfreq, mean(log(pxx),2),'LineWidth',4)
fps = 20;
fstop = 5; %Hz
d = designfilt('lowpassfir','SampleRate',fps, 'PassbandFrequency',fstop-.5, ...
   'StopbandFrequency',fstop+.5,'PassbandRipple',0.5, ...
   'StopbandAttenuation',90,'DesignMethod','kaiserwin');%could also use butter,cheby1/2,equiripple
f = single(filtfilt(d, double(f)));

%% LOWPASS 2 (commented out)
% fps = 20;
% fnyq = fps/2;
% fstop = 2; %Hz
% n = 100;
% wstop = fstop/fnyq;
% d = designfilt('lowpassfir','SampleRate',fps, 'PassbandFrequency',fstop, ...
%    'StopbandFrequency',fstop+1,'PassbandRipple',0.1, ...
%    'StopbandAttenuation',30,'DesignMethod','kaiserwin');%could also use butter,cheby1/2,equiripple
% f = single(filtfilt(d, double(f)));

% BANDPASS FILTER
% fps = 20;
% fnyq = fps/2;
% fstop = 1/10; %Hz
% n = fps * 2/fstop;
% wstop = fstop/fnyq;
% d = designfilt('bandpassfir', 'StopbandFrequency1', 4, 'PassbandFrequency1', 4.5,...
%    'PassbandFrequency2', 9, 'StopbandFrequency2', 10,...
%    'StopbandAttenuation1', 60, 'PassbandRipple', .1, ...
%    'StopbandAttenuation2', 60, 'SampleRate', 20);
% fbp = single(filtfilt(d, double(f)));







% NORMALIZE TO A BASELINE
fnan = f;
fnan( bsxfun(@ge, f, mean(f,1)+std(f,[],1))) = NaN;
f = bsxfun(@rdivide, bsxfun(@minus, f, nanmean(fnan,1)), nanstd(fnan,1));
for k=1:numel(R)
   R(k).Trace = f(:,k); 
end

%% NON-TASK-RELATED ZERO-LAG CORRELATION (commented out)
[C,P,rLow,rUp] = corrcoef(f);
title('Zero-Lag Cross-Correlation Coefficient between ROIs')
% b = false(nRoi,1);
% set(R,'Color',[0 1 0])
% for k=1:nRoi
%    RRef = R(k);
%    coR = P(k,:) > .95;
%    if sum(coR)>1
% 	 RCor = R(coR); 
% 	 RRef.Color = [1 0 0];
% % 	  if any(RRef.centroidSeparation(RCor) < 50,1)
% 		 b = b | coR';
% 		 showWithText(cat(1,RRef, RCor(:))), pause;
% 		 % 		 set(R(coR), 'Color', [rand rand rand])
% % 	  end
%    end
% end

% % FIND PEAKS
% fstd = std(f,[],1);
% parfor kRoi = 1:numel(R)
%    mpp = 2*(fstd(kRoi));
%    [pks(kRoi).amp, pks(kRoi).loc, pks(kRoi).width, pks(kRoi).prom] = ...
% 	  findpeaks(double(f(:,kRoi)), 'MinPeakProminence',mpp); 
% end
% % for k=1:numel(R)
% %    plot(f(:,k)), hold on, plot(pks(k).loc, pks(k).amp, 'o'), pause, cla, 
% % end
% peakRaster = spalloc(size(f,1), size(f,2), numel(cat(1,pks.loc)));
% for k=1:nRoi
%    peakRaster(pks(k).loc, k) = pks(k).prom; 
% end
%

%% LAGGED CROSS-CORRELATION
% maxlag = 40;
% Crk = zeros(2*maxlag+1,nRoi, nRoi,'single');
% [~,lags] = xcorr(f(1:2:end,1), f(1:2:end,2) , maxlag, 'coeff');
% parfor kRef = 1:nRoi
%    for k=1:nRoi
% 	  Crk(:,k, kRef) = xcorr(f(1:2:end,kRef), f(1:2:end,k) , maxlag, 'coeff');
%    end
% end
% fps = 20;
% maxlag = 10*fps;
% maxlag = 5;
% [~,lags] = xcorr(f(:,1), f(:,2) , maxlag, 'coeff');
% tLag = lags(:)/20;
% nLag = numel(lags);
% xFit.poly1 = [ones(nLag,1), tLag];
% xFit.poly2 = [ones(nLag,1), tLag, tLag.^2];
% xFit.poly3 = [ones(nLag,1), tLag, tLag.^2, tLag.^3];
% fitFields = fields(xFit);
% % NON-TASK-RELATED LAGGED CROSS-CORRELATION
% X = xFit.poly2;
% cubFit = zeros([nRoi nRoi 3]);
% Crk = zeros(maxlag,nRoi, nRoi);
% parfor kRef = 1:nRoi
%    for k=1:nRoi
% 	  Crk(:,k, kRef) = xcorr(f(:,kRef), f(:,k) , maxlag, 'coeff');
% 	  cubFit(kRef, k, :) = (X' * X) \ X' * C;
% 	  % 	  [cpk.amp, cpk.loc, cpk.width, cpk.prom] = ...
% 	  % 		 findpeaks(double(C),'MinPeakProminence',.001);
% 	  % 	  plot(tLag, C,':'), hold on,
% 	  % 	  plot(tLag(cpk.loc), cpk.amp, 'o')
% 	  % 	  for nFit = 1:numel(fitFields)
% 	  % 		 X = xFit.(fitFields{nFit});
% 	  % 		 % 		 fitCoeff.(fitFields{nFit}) = (X' * X) \ X' * C;
% 	  % 		 % 		 cFit.(fitFields{nFit}) = X * fitCoeff.(fitFields{nFit});
% 	  % 		 % 		 plot(tLag, cFit.(fitFields{nFit}))
% 	  % 		 fitCoeff = (X' * X) \ X' * C;
% 	  % 		 cFit = X * fitCoeff;
% 	  % 		 hLine = plot(tLag, cFit);
% 	  % 		 text(double(tLag(maxlag+20*nFit)), double(cFit(maxlag+20*nFit))-.01,...
% 	  % 			sprintf(['%s - \n',repmat('%+5.5f\n',1,numel(fitCoeff))], fitFields{nFit}, fitCoeff),...
% 	  % 			'Color',hLine.Color)
% 	  % 	  end
% 	  % 	  pause, cla
%    end
% end
% % for k=1:numel(R)
% %    plot(lags./20, c(:,k)), hold on, plot(lags(pks(k).loc)./20, pks(k).amp, 'o'), pause, cla, 
% % end
% normChannels = @(A) bsxfun(@rdivide,...
%    bsxfun(@minus, A, min(min(A,[],1),[],2)),...
%    max(max(A,[],1),[],2) - min(min(A,[],1),[],2));
% cf2 = cubFit(:,:,2);
% cf2pos = cf2;
% cf2neg = cf2;
% cf2pos(cf2pos<0) = 0;
% cf2neg(cf2neg>0) = 0;
% cubFitNorm = normChannels(cat(3,cf2pos, cubFit(:,:,1), -cf2neg));
% for k=1:3
%    cubFitWhite(:,:,k) = histeq(cubFitNorm(:,:,k)); 
% end
% % cubFitWhite(:,:,3) = 1-cubFitWhite(:,:,3);
% cfSum = sum(bsxfun(@times, [1 0 -1], squeeze(sum(cubFitWhite,1))),2);
% [~,idx] = sort(cfSum);
% RUnsort = R;
% % R = R(idx);
% % for kRef = 1:nRoi
% %    for k=1:nRoi
% % 	  R(k).Color = squeeze(cubFitWhite(kRef,k,:)); 
% %    end
% %    R(kRef).Color = [0 0 0];
% %    show(cat(1,R(kRef), R(~(R(kRef).isInBoundingBox(R))))), pause
% % end

%% LOAD TRIAL AND LICK DATA (trial)
trial = importTrialData();
nTrial = size(trial,1);
try
lickdata = importLickData();
catch
%    lickdata = importLickDataDevalue();
getthislickdata
end
% LOAD VIDEO TIMESTAMP INFO
d = dir('Processed_VideoFiles*');
[~,idx] = max(datenum({d.date}));
load(d(idx).name);
info = getInfo(allVidFiles);
t = cat(1,info.time);

% FIND FRAME INDICES ALIGNED WITH TRIAL STARTS
trialIdx.short = find(trial.stim < 1.5);
trialIdx.long = find(trial.stim >=1.5);
trialIdx.longovershort = cat(1,trialIdx.long, trialIdx.short);
frameIdx.allTrials = find(any(bsxfun(@ge, t, trial.tstart') & bsxfun(@lt, circshift(t,1), trial.tstart'),2));
frameIdx.shortTrial = frameIdx.allTrials(trialIdx.short);
frameIdx.longTrial = frameIdx.allTrials(trialIdx.long);
maxInterTrialIdx = max(diff(frameIdx.allTrials));
minInterTrialIdx = min(diff(frameIdx.allTrials));

% FIND FRAME INDICES ALIGNED WITH LICKS
frameIdx.allLicks = find(any(bsxfun(@ge, t, lickdata.tlick') & bsxfun(@lt, circshift(t,1), lickdata.tlick'),2));
frameIdx.shortLick = frameIdx.allLicks(trialIdx.short);
frameIdx.longLick = frameIdx.allLicks(trialIdx.long);

%% SHOW ROIs
h = show(R);
print(h.fig, fullfile(figDir,'Regions of Interest'), '-dpng')
nExample = min(10,nRoi);
exampleRoiIdx = round(linspace(1,nRoi, nExample));
fplot = norm01(f(:,exampleRoiIdx));
strips(fplot)
fplot = bsxfun(@plus, fplot, cumsum(ones(1,nExample)));
hFig = figure;
plot(t,fplot); xlim([t(1) t(end)]); ylim([.9 nExample+1]);
title('Example ROI Traces'), xlabel('time (seconds)');
set(gca, 'FontSize', 12, 'FontWeight', 'bold')
print(gcf,fullfile(figDir,get(get(gca,'Title'), 'String')), '-dpng')

%% GET LICK NOISE
lick = zeros(size(f,1),1);
lick(frameIdx.allLicks) = 1;
df = diff(double([f(1,:) ; f]), 1,1);
fNoise = zeros(size(f));
for k=1:size(df,2)
   fNoise(:,k) = conv(lick, df(:,k), 'same');
end


%% SORT INTO TRIAL TRIGGERED ROWS (overlapping)       [ time X trial X roi]
% 
% ft = zeros(maxInterTrialIdx, nTrial, nRoi, 'single');
% ftLick = zeros(maxInterTrialIdx, nTrial, nRoi, 'single');
% preTrialMean = zeros([1, nTrial, nRoi]);
% trialMedian = zeros([1, nTrial, nRoi]);
% for kRoi = 1:numel(R);
%    for kTrial=1:nTrial
% 	  idx = frameIdx.allTrials(kTrial)-20;
% 	  if idx < 0 || (idx+maxInterTrialIdx-1) > size(f,1)
% 		 continue
% 	  end
% 	  ft(:,kTrial, kRoi) = f( idx:(idx+maxInterTrialIdx-1), kRoi);
% 	  preTrialMean(1,kTrial,kRoi) = mean(f(idx-5:idx-1,kRoi));
% 	  trialMedian(1,kTrial,kRoi) = median(f(idx-5:idx-1,kRoi));
% 	  idxLick = frameIdx.allLicks(find(frameIdx.allLicks > (idx+20), 1, 'first')) - 20;
% 	  ftLick(:,kTrial, kRoi) = f( idxLick:(idxLick+maxInterTrialIdx-1), kRoi);
%    end
% end
% % trialRange = range(ft,1);
% % trialStd = std(ft,1);
% % ft = bsxfun( @rdivide, bsxfun(@minus, ft, preTrialMean), trialStd);
% ft = normZ(ft);
% 
% trialTrigAvg = squeeze(mean(ft,2));
% shortTrigAvg = squeeze(mean(ft(:,trialIdx.short,:),2));
% longTrigAvg = squeeze(mean(ft(:,trialIdx.long,:),2));
% diffTrigAvg = longTrigAvg - shortTrigAvg;
% % BOTH
% [~,trialTrigSort] = sort(trialTrigAvg(21,:));
% clf, hIm = imagesc(trialTrigAvg(1:(6*20+1), trialTrigSort)'); 
% title('Trial-Triggered Mean - Both Sounds (normalized)');
% flAx = gca;
% flAx.XTick = -20:20:5*20;
% flAx.XTickLabel = {'-2','-1', '0', '1'  , '2'   '3'   '4' , '5'};
% xlabel('time')
% ylabel('neuron')
% set(gca, 'FontSize', 12, 'FontWeight', 'bold')
% % SHORT
% % [~,trialTrigSort] = sort(trialTrigAvg(21,:));
% clf, hIm = imagesc(shortTrigAvg(1:(6*20+1), trialTrigSort)'); 
% title('Trial-Triggered Mean - SHORT (normalized)');
% flAx = gca;
% flAx.XTick = -20:20:5*20;
% flAx.XTickLabel = {'-2','-1', '0', '1'  , '2'   '3'   '4' , '5'};
% xlabel('time')
% ylabel('neuron')
% set(gca, 'FontSize', 12, 'FontWeight', 'bold')
% % LONG
% % [~,trialTrigSort] = sort(trialTrigAvg(21,:));
% clf, hIm = imagesc(longTrigAvg(1:(6*20+1), trialTrigSort)'); 
% title('Trial-Triggered Mean - LONG (normalized)');
% flAx = gca;
% flAx.XTick = -20:20:5*20;
% flAx.XTickLabel = {'-2','-1', '0', '1'  , '2'   '3'   '4' , '5'};
% xlabel('time')
% ylabel('neuron')
% set(gca, 'FontSize', 12, 'FontWeight', 'bold')
% % DIFFERENCE
% clf, hIm = imagesc(diffTrigAvg(1:(6*20+1), trialTrigSort)'); 
% title('Trial-Triggered Mean - DIFFERENCE (normalized)');
% flAx = gca;
% flAx.XTick = -20:20:5*20;
% flAx.XTickLabel = {'-2','-1', '0', '1'  , '2'   '3'   '4' , '5'};
% xlabel('time')
% ylabel('neuron')
% set(gca, 'FontSize', 12, 'FontWeight', 'bold')




%% SHORTER TRIAL LENGTH SOUND TRIGGERED
trialLength = 6*20;
ft6 = zeros(trialLength, nTrial, nRoi);
ftLick = zeros(trialLength, nTrial, nRoi);
soundTriggeredLick = zeros(trialLength, nTrial);
lickTriggeredLick = zeros(trialLength, nTrial);
for kRoi = 1:numel(R);
   for kTrial=1:nTrial
	  idx = frameIdx.allTrials(kTrial)-20;
	  if idx < 0 || (idx+trialLength-1) > size(f,1)
		 continue
	  end
	  ft6(:,kTrial, kRoi) = f( idx:(idx+trialLength-1), kRoi);
	  % GET INDICES OF FIRST LICK AFTER SOUND (sound onset = trial onset)
	  idxLick = frameIdx.allLicks(find(frameIdx.allLicks > (idx+20), 1, 'first')) - 20;
	  ftLick(:,kTrial, kRoi) = f( idxLick:(idxLick+trialLength-1), kRoi);
	  soundTriggeredLick(:,kTrial) = lick(idx:(idx+trialLength-1));
	  lickTriggeredLick(:,kTrial) = lick(idxLick:(idxLick+trialLength-1));
   end   
   k=kRoi;
   if any(k==exampleRoiIdx)
	  ex.soundtrig.long = ft6(:,trialIdx.long,k);
	  ex.soundtrig.short = ft6(:,trialIdx.short,k);
	  ex.soundtrig.longovershort = cat(2, ex.soundtrig.long, ex.soundtrig.short);
	  lickoverlay.long = soundTriggeredLick(:, trialIdx.long);
	  lickoverlay.short = soundTriggeredLick(:, trialIdx.short);
	  im = cat(3, norm01(ex.soundtrig.longovershort)',...
		 .6*cat(2, lickoverlay.long, zeros(size(lickoverlay.short)))',...
		 .8*cat(2, zeros(size(lickoverlay.long)), lickoverlay.short )' );
	  hIm = image(im, 'XData', -1:(1/20):5 );
	  title(sprintf('Tone-Triggered Trace with Licks - LONG-TONE (green), SHORT-TONE (blue) - Example Neuron %i', k))
	  set(gca, 'FontSize', 12, 'FontWeight', 'bold',...
		 'YTick',[],...
		 'Position',[0 0 1 1])
	  print(gcf,fullfile(figDir,get(get(gca,'Title'), 'String')), '-dpng')
	  % 	  imagesc(-1:(1/20):5,[], ft6(:,:,k))
	  % 	  title(sprintf('First-Lick-Triggered Trace - ALL TRIALS - Example Neuron %i', k))
	  % 	  xlabel('Time - 0 = tone onset'), ylabel('Trial')
	  % 	  set(gca, 'FontSize', 12, 'FontWeight', 'bold')
	  % 	  print(gcf,fullfile(figDir,get(get(gca,'Title'), 'String')), '-dpng')
	  imagesc(-1:(1/20):5,[], normZ(squeeze(ft6( :, trialIdx.long, k)))')
	  title(sprintf('Tone-Triggered Trace - LONG-TONE TRIALS - Example Neuron %i', k))
	  xlabel('Time - 0 = tone onset'), ylabel('Trial')
	  set(gca, 'FontSize', 12, 'FontWeight', 'bold')
	  print(gcf,fullfile(figDir,get(get(gca,'Title'), 'String')), '-dpng')
	  imagesc(-1:(1/20):5,[], normZ(squeeze(ft6(:, trialIdx.short, k)))')
	  title(sprintf('Tone-Triggered Trace - SHORT-TONE TRIALS - Example Neuron %i', k))
	  xlabel('Time - 0 = tone onset'), ylabel('Trial')
	  set(gca, 'FontSize', 12, 'FontWeight', 'bold')
	  print(gcf,fullfile(figDir,get(get(gca,'Title'), 'String')), '-dpng')
   end
end
% trialRange = range(ft6,1);
% trialStd = std(ft6,1);
% ft6 = bsxfun( @rdivide, bsxfun(@minus, ft6, mean(ft6,1)), trialStd);
ft6 = normZ(ft6);

trialTrigAvg = squeeze(mean(ft6,2));
shortTrigAvg = squeeze(mean(ft6(:,trialIdx.short,:),2));
longTrigAvg = squeeze(mean(ft6(:,trialIdx.long,:),2));
diffTrigAvg = longTrigAvg - shortTrigAvg;
% BOTH
[~,trialTrigSort] = sort(trialTrigAvg(21,:));
clf, imagesc(-1:(1/20):5,[],trialTrigAvg(:, trialTrigSort)'); 
title('Trial-Triggered Mean -  BOTH Sounds (normalized)');
xlabel('Time - 0 = sound onset')
ylabel('Neuron')
set(gca, 'FontSize', 12, 'FontWeight', 'bold')
print(gcf,fullfile(figDir,get(get(gca,'Title'), 'String')), '-dpng')
% SHORT
% [~,trialTrigSort] = sort(trialTrigAvg(21,:));
clf, imagesc(-1:(1/20):5,[],shortTrigAvg(:, trialTrigSort)'); 
title('Trial-Triggered Mean - SHORT (normalized)');
xlabel('Time - 0 = sound onset')
ylabel('Neuron')
set(gca, 'FontSize', 12, 'FontWeight', 'bold')
print(gcf,fullfile(figDir,get(get(gca,'Title'), 'String')), '-dpng')
% LONG
% [~,trialTrigSort] = sort(trialTrigAvg(21,:));
clf, imagesc(-1:(1/20):5,[],longTrigAvg(:, trialTrigSort)'); 
title('Trial-Triggered Mean - LONG (normalized)');
xlabel('Time - 0 = sound onset')
ylabel('Neuron')
set(gca, 'FontSize', 12, 'FontWeight', 'bold')
print(gcf,fullfile(figDir,get(get(gca,'Title'), 'String')), '-dpng')
% DIFFERENCE
clf, imagesc(-1:(1/20):5,[],diffTrigAvg(:, trialTrigSort)'); 
title('Trial-Triggered Mean - DIFFERENCE (normalized)');
xlabel('Time - 0 = sound onset')
ylabel('Neuron')
set(gca, 'FontSize', 12, 'FontWeight', 'bold')
print(gcf,fullfile(figDir,get(get(gca,'Title'), 'String')), '-dpng')

%% PLOT BEHAVIOR (LICKS)
clf
imagesc(-1:(1/20):5,[],lickTriggeredLick'); 
title('Lick-Triggered-Lick - BOTH TONES');
xlabel('Time - 0 = first lick after tone onset')
ylabel('Trial')
set(gca, 'FontSize', 12, 'FontWeight', 'bold')
print(gcf,fullfile(figDir,get(get(gca,'Title'), 'String')), '-dpng')
clf
imagesc(-1:(1/20):5,[],lickTriggeredLick(:,trialIdx.long)'); 
title('Lick-Triggered-Lick - LONG TONE')
xlabel('Time - 0 = first lick after tone onset')
ylabel('Trial')
print(gcf,fullfile(figDir,get(get(gca,'Title'), 'String')), '-dpng')
clf
imagesc(-1:(1/20):5,[],lickTriggeredLick(:,trialIdx.short)'); 
title('Lick-Triggered-Lick - SHORT TONE')
xlabel('Time - 0 = first lick after tone onset')
ylabel('Trial')
print(gcf,fullfile(figDir,get(get(gca,'Title'), 'String')), '-dpng')
clf
imagesc(-1:(1/20):5,[],soundTriggeredLick'); 
title('Sound-Triggered-Lick - BOTH TONES');
xlabel('Time - 0 = tone onset')
ylabel('Trial')
set(gca, 'FontSize', 12, 'FontWeight', 'bold')
print(gcf,fullfile(figDir,get(get(gca,'Title'), 'String')), '-dpng')
clf
imagesc(-1:(1/20):5,[],soundTriggeredLick(:,trialIdx.long)'); 
title('Sound-Triggered-Lick - LONG TONE')
xlabel('Time - 0 = tone onset')
ylabel('Trial')
print(gcf,fullfile(figDir,get(get(gca,'Title'), 'String')), '-dpng')
clf
imagesc(-1:(1/20):5,[],soundTriggeredLick(:,trialIdx.short)'); 
title('Sound-Triggered-Lick - SHORT TONE')
xlabel('Time - 0 = tone onset')
ylabel('Trial')
print(gcf,fullfile(figDir,get(get(gca,'Title'), 'String')), '-dpng')

%% LICK TRIGGERED
ftLickMean = squeeze(mean(ftLick,2));
shortLickAvg = squeeze(mean(ftLick(:,trialIdx.short,:),2));
longLickAvg = squeeze(mean(ftLick(:,trialIdx.long,:),2));
diffLickAvg = longLickAvg - shortLickAvg;
% NORMALIZATION
ftLickMeanNorm = bsxfun(@rdivide, bsxfun(@minus, ftLickMean,  mean(ftLickMean,1)), std(ftLickMean,1, 1));
shortLickMeanNorm = bsxfun(@rdivide, bsxfun(@minus, shortLickAvg,  mean(shortLickAvg,1)), std(shortLickAvg,1, 1));
longLickMeanNorm = bsxfun(@rdivide, bsxfun(@minus, longLickAvg,  mean(longLickAvg,1)), std(longLickAvg,1, 1));
diffLickMeanNorm = bsxfun(@rdivide, bsxfun(@minus, diffLickAvg,  mean(diffLickAvg,1)), std(diffLickAvg,1, 1));
% BOTH
[~,lickTrigSort] = sort(ftLickMeanNorm(21,:));
clf, imagesc(-1:(1/20):5,[],ftLickMeanNorm(1:(6*20), lickTrigSort)'); 
title('Lick-Triggered Mean - Both Sounds (normalized after Average)');
xlabel('time')
ylabel('Neuron')
set(gca, 'FontSize', 12, 'FontWeight', 'bold')
print(gcf,fullfile(figDir,get(get(gca,'Title'), 'String')), '-dpng')
% SHORT
% [~,trialTrigSort] = sort(trialTrigAvg(21,:));
clf, imagesc(-1:(1/20):5,[],shortLickMeanNorm(1:(6*20), lickTrigSort)'); 
title('Lick-Triggered Mean - SHORT (normalized after Average)');
xlabel('time')
ylabel('Neuron')
set(gca, 'FontSize', 12, 'FontWeight', 'bold')
print(gcf,fullfile(figDir,get(get(gca,'Title'), 'String')), '-dpng')
% LONG
% [~,trialTrigSort] = sort(trialTrigAvg(21,:));
clf, imagesc(-1:(1/20):5,[],longLickMeanNorm(1:(6*20), lickTrigSort)'); 
title('Lick-Triggered Mean - LONG (normalized after Average)');
xlabel('time')
ylabel('Neuron')
set(gca, 'FontSize', 12, 'FontWeight', 'bold')
print(gcf,fullfile(figDir,get(get(gca,'Title'), 'String')), '-dpng')
% DIFFERENCE
clf, imagesc(-1:(1/20):5,[],diffLickMeanNorm(1:(6*20), lickTrigSort)'); 
title('Lick-Triggered Mean - DIFFERENCE (normalized after Average)');
xlabel('time')
ylabel('Neuron')
set(gca, 'FontSize', 12, 'FontWeight', 'bold')
print(gcf,fullfile(figDir,get(get(gca,'Title'), 'String')), '-dpng')

%% LICK-TRIGGERED (PRE-NORMALIZED) WITH EXAMPLE ROI ALL TRIALS
ftLickZ = normZ(ftLick);
firstLickTrace = zeros(nTrial,120,nRoi);
% clf
for k = 1:nRoi
   firstLickTrace(:,:,k) = normZ(squeeze(ftLickZ(:,:,k)))';
   if any(k==exampleRoiIdx)
	  % 	  imagesc(-1:(1/20):5,[], firstLickTrace(:,:,k))
	  % 	  title(sprintf('First-Lick-Triggered Trace - ALL TRIALS - Example Neuron #%i ',k))
	  % 	  xlabel('Time - 0 = first lick after tone onset'), ylabel('Trial')
	  % 	  set(gca, 'FontSize', 12, 'FontWeight', 'bold')
	  % 	  print(gcf,fullfile(figDir,get(get(gca,'Title'), 'String')), '-dpng')
	  imagesc(-1:(1/20):5,[], firstLickTrace( trialIdx.long, :, k))
      title(sprintf('First-Lick-Triggered Trace - LONG-TONE TRIALS - Example Neuron %i', k))
      xlabel('Time - 0 = first lick after tone onset'), ylabel('Trial')
      set(gca, 'FontSize', 12, 'FontWeight', 'bold')
	  print(gcf,fullfile(figDir,get(get(gca,'Title'), 'String')), '-dpng')
	  imagesc(-1:(1/20):5,[], firstLickTrace( trialIdx.short, :, k))
      title(sprintf('First-Lick-Triggered Trace - SHORT-TONE TRIALS - Example Neuron %i', k))
      xlabel('Time - 0 = first lick after tone onset'), ylabel('Trial')
      set(gca, 'FontSize', 12, 'FontWeight', 'bold')
	  print(gcf,fullfile(figDir,get(get(gca,'Title'), 'String')), '-dpng')	  
   end
end
firstLickTrialNormedAvg = squeeze(mean(firstLickTrace,1))';
shortLickTrialNormedAvg = squeeze(mean(firstLickTrace(trialIdx.short,:,:),1))';
longLickTrialNormedAvg = squeeze(mean(firstLickTrace(trialIdx.long,:,:),1))';
diffLickTrialNormedAvg = longLickTrialNormedAvg - shortLickTrialNormedAvg;
print(gcf,fullfile(figDir,get(get(gca,'Title'), 'String')), '-dpng')
clf
imagesc(-1:(1/20):5,[], firstLickTrialNormedAvg(lickTrigSort,:));
title('First-Lick-Triggered Traces - BOTH TONES Average Across Trials (sorted)')
xlabel('Time - 0 = first lick after tone onset')
ylabel('Neuron')
set(gca, 'FontSize', 12, 'FontWeight', 'bold')
print(gcf,fullfile(figDir,get(get(gca,'Title'), 'String')), '-dpng')
clf
imagesc(-1:(1/20):5,[], shortLickTrialNormedAvg(lickTrigSort,:));
title('First-Lick-Triggered Traces - SHORT TONE Average Across Trials (sorted)')
xlabel('Time - 0 = first lick after tone onset')
ylabel('Neuron')
set(gca, 'FontSize', 12, 'FontWeight', 'bold')
print(gcf,fullfile(figDir,get(get(gca,'Title'), 'String')), '-dpng')
clf
imagesc(-1:(1/20):5,[], longLickTrialNormedAvg(lickTrigSort,:));
title('First-Lick-Triggered Traces - LONG TONE Average Across Trials (sorted)')
xlabel('Time - 0 = first lick after tone onset')
ylabel('Neuron')
set(gca, 'FontSize', 12, 'FontWeight', 'bold')
print(gcf,fullfile(figDir,get(get(gca,'Title'), 'String')), '-dpng')
clf
imagesc(-1:(1/20):5,[], diffLickTrialNormedAvg(lickTrigSort,:));
title('First-Lick-Triggered Traces - DIFFERENCE Average Across Trials (sorted)')
xlabel('Time - 0 = first lick after tone onset')
ylabel('Neuron')
set(gca, 'FontSize', 12, 'FontWeight', 'bold')
print(gcf,fullfile(figDir,get(get(gca,'Title'), 'String')), '-dpng')



























%% REST (COMMENTED OUT)
% 
% 
% 
% 
% ftLickStd = squeeze(std(ftLick,1, 2));
% licktrace(frameIdx.allLicks) = 1;
% lickft = zeros(maxInterTrialIdx, nTrial, nRoi, 'single');
% %%
% for kTrial=1:nTrial
%    idx = frameIdx.allTrials(kTrial);
%    if idx < 0 || (idx+maxInterTrialIdx-1) > size(licktrace,1)
% 	  continue
%    end
%    lickft(:,kTrial) = licktrace(idx:(idx+maxInterTrialIdx-1));
% end
% for k=1:nRoi
%    [cLick(:,k),lags] = xcov(f(:,k), licktrace,120,'coeff');
%    %    plot(lags, c), ylim([-.5 .5]), pause,
% end
% 
% 
% 
% 
% ftLickStd = squeeze(std(ftLick,1, 2));
% ftLickStdNorm = bsxfun(@minus, ftLickStd, mean(ftLickStd,1));
% [~,licksort] = sort(ftLickMeanNorm(21,:));
% clf, hIm = imagesc(ftLickMeanNorm(1:(6*20+1), licksort)'); 
% title('First-Lick-Of-Trial-Triggered Mean (normalized)');
% flAx = gca;
% flAx.XTick = -20:20:5*20;
% flAx.XTickLabel = {'-2','-1', '0', '1'  , '2'   '3'   '4' , '5'};
% xlabel('time')
% ylabel('Neuron')
% set(gca, 'FontSize', 12, 'FontWeight', 'bold')
% clf, imagesc(ftLickStdNorm'), title('First-Lick-Of-Trial-Triggered Standard Deviation (normalized)')
% clf, imagesc(ltMeanNorm'), title('Lick-Triggered Mean (normalized)')
% clf, imagesc(ltMeanNorm'), title('Lick-Triggered Mean (normalized)')
% ltLag = 80;
% ltMean = zeros(2*ltLag+1,nRoi);
% for kRoi = 1:nRoi
%    for k=1:(ltLag*2+1)
% 	  tau=k-ltLag+1;
% 	  lickIdx = frameIdx.allLicks+tau;
% 	  lickIdx = lickIdx(lickIdx>=1 & lickIdx <=size(f,1));
% 	  ltMean(k,kRoi) = mean(f(max(1,lickIdx),kRoi), 1);
%    end
% end
% ltMeanNorm = bsxfun(@rdivide, bsxfun(@minus, ltMean,  mean(ltMean,1)), std(ltMean,1,1));
% clf, imagesc(ltMeanNorm'), title('Lick-Triggered Mean (normalized)')
% [~,ltmnIdx] = sort(max(ltMeanNorm(ltLag-5:ltLag+5,:),[],1));
% clf, surf(ltMeanNorm(:,ltmnIdx), 'FaceColor','interp','FaceLighting','phong','EdgeColor','none'); axis tight, camlight left
% lickImpulse = zeros(size(f,1),1);
% lickImpulse(frameIdx.allLicks) = 1;
% ltSig = zeros(numel(lickImpulse), nRoi);
% for kRoi = 1:nRoi
%    ltSig(:,kRoi) = conv(lickImpulse, ltMeanNorm(:,kRoi), 'same');
% end
% clf, plot(ltSig(:,60)/20)
% hold on
% plot(f(:,60))
% 
% 
% 
% % parfor kRoi = 1:numel(R);
% %    for kTrial=1:nTrial
% % 	  [peaks(kTrial,kRoi).amp,peaks(kTrial,kRoi).locs,peaks(kTrial,kRoi).width,peaks(kTrial,kRoi).prominence] =...
% % 		 findpeaks(double(ft(:,kTrial,kRoi)), 'MinPeakProminence',3);
% %    end
% % end
% 
% % trialTrigAvg = bsxfun(@rdivide, bsxfun(@minus,trialTrigAvg, min(trialTrigAvg,[],1)), range(trialTrigAvg,1));
% 
% clf, hSurf = surf(ft(:, trialIdx.short, 108), 'FaceColor','interp','FaceLighting','phong','EdgeColor','none'); axis tight, camlight left
% 
% % BINARY
% ftBin.pos = bsxfun( @ge, ft, .5);
% ftBin.neg = bsxfun( @le, ft, -.5);
% stim.shortBin.pos = ftBin.pos(:,trialIdx.short,:);
% stim.shortBin.neg = ftBin.neg(:,trialIdx.short,:);
% stim.longBin.neg = ftBin.neg(:,trialIdx.long,:);
% stim.longBin.pos = ftBin.pos(:,trialIdx.long,:);
% stim.shortBin.sum = sum(int8(stim.shortBin.pos),2) - sum(int8(stim.shortBin.neg),2);
% stim.longBin.sum = sum(int8(stim.longBin.pos),2) - sum(int8(stim.longBin.neg),2);
% 
% stim.binSumDiff = stim.longBin.sum - stim.shortBin.sum;
% [cDiff,lags] = xcorr(squeeze(stim.binSumDiff),  minInterTrialIdx, 'coeff');
% [cShort,lags] = xcorr(squeeze(stim.shortBin.sum),  minInterTrialIdx, 'coeff');
% [cLong,lags] = xcorr(squeeze(stim.longBin.sum),  minInterTrialIdx, 'coeff');
% cDiff = reshape(cDiff,size(cDiff,1),nRoi,nRoi);
% cShort = reshape(cShort,size(cShort,1),nRoi,nRoi);
% cLong = reshape(cLong,size(cLong,1),nRoi,nRoi);
% 
% cbs = bsxfun(@minus, cDiff, (cDiff(1,:,:)+cDiff(end,:,:))/2);
% 
% 
% 
% tau = t(1:120);
%  f = bsxfun( @rdivide, bsxfun( @minus, f, min(f,[],1)), range(f,1));
% stimKernel = exp(-(2*tau)/sqrt(2) - exp(-(15*tau)/(sqrt(2))));
% stimTrace.long = conv(stimTrace.long, stimKernel);
% stimTrace.long = stimTrace.long(1:numel(t));
% stimTrace.short = conv(stimTrace.short, stimKernel);
% stimTrace.short = stimTrace.short(1:numel(t));
% skFilt.long = squeeze(filter(stimTrace.long, 1, bsxfun(@minus, f , mean(f,1))));
% skFilt.short = squeeze(filter(stimTrace.short, 1, bsxfun(@minus, f , mean(f,1))));


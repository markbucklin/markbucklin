%% INLINE FUNCTIONS
normsig.z = @(v) bsxfun(@rdivide, bsxfun(@minus, v, nanmean(v,1)), nanstd(v,[],1));
normsig.poslt1 = @(v) bsxfun(@rdivide, bsxfun(@minus, v, nanmin(v,[],1)), range(v,1));
normsig.zmlt1 = @(v) bsxfun(@rdivide, bsxfun(@minus, v, nanmean(v,1)), nanmax(abs(v),[],1));
normsig.poslog = @(v) log( bsxfun(@plus, bsxfun(@minus, v, nanmin(v,[],1)) , nanstd(v,[],1)));



%% FOLDER FOR SAVING FIGURES
figDir = [pwd,filesep,'Figures'];
if ~isdir(figDir)
   mkdir(figDir)
else
   figFiles = dir(figDir);
   if ~all([figFiles.isdir])
	  oldFigDir =  [pwd,filesep,'Older Figures'];
	  if ~isdir(oldFigDir)
		 mkdir(oldFigDir)
	  end
	  oldFigDir = [oldFigDir, filesep, 'Figures ',datestr(now,'ddmmmHHMMPM')];
	  mkdir(oldFigDir)
	  movefile([figDir,filesep,'*'], oldFigDir, 'f');
   end
end

%% LOAD ROI DATA (R)
file.roi = dir([pwd,'\Re_Processed_ROIs_*.mat']);
if isempty(file.roi)
   file.roi = dir([pwd,'\Processed_ROIs_*.mat']);
end
[~,idx] = max(datenum({file.roi.date}));
load(file.roi(idx).name);
nRoi = numel(R);
X = single([R.Trace]);	% Can also use	X = single([R.RawTrace]);
X = normsig.zmlt1(X);
for k=1:nRoi
   R(k).Trace = X(:,k); % Is this beneficial?
end

%% LOAD TRIAL AND LICK DATA (trial)
bhv = loadBehaviorData();
t = bhv.t; %TODO: FIX MISSING FRAMES (interpolate?
nTrial = nanmin(200, size(bhv.frameidx.alltrials,1));
nFrames = size(X,1);

% trial = importTrialData();
% nTrial = nanmin(200, size(trial,1));
% trial = trial(1:nTrial,:);
% try
%    lickdata = importLickData();
% catch
%    %    lickdata = importLickDataDevalue();
%    % getthislickdata
%    load('lickdata.mat')
% end
% % LOAD VIDEO TIMESTAMP INFO
% file.vid = dir('Processed_VideoFiles*');
% [~,idx] = max(datenum({file.vid.date}));
% load(file.vid(idx).name);
% info = getInfo(allVidFiles);
% t = cat(1,info.time);
%
% % FIND FRAME INDICES ALIGNED WITH TRIAL STARTS
% trialIdx.short = find(trial.stim == nanmin(trial.stim));
% trialIdx.long = find(trial.stim == max(trial.stim));
% trialIdx.longovershort = cat(1,trialIdx.long, trialIdx.short);
% frameidx.alltrials = find(any(bsxfun(@ge, t, trial.tstart') & bsxfun(@lt, circshift(t,1), trial.tstart'),2));
% frameidx.shorttrial =frameidx.alltrials(trialIdx.short);
% frameidx.longtrial = frameidx.alltrials(trialIdx.long);
%
% % FIND FRAME INDICES ALIGNED WITH LICKS
% frameidx.alllicks = find(any(bsxfun(@ge, t, lickdata.tlick') & bsxfun(@lt, circshift(t,1), lickdata.tlick'),2));
% frameidx.shortlick = frameidx.alllicks(trialIdx.short);
% frameidx.longlick = frameidx.alllicks(trialIdx.long);
% LOAD BEHAVIOR DATA (including trial structure)


%% SHOW ROIs
h = show(R);
print(h.fig, fullfile(figDir,'Regions of Interest'), '-dpng')
nExample = nanmin(3,nRoi);
exampleRoiIdx = round(linspace(1,nRoi, nExample));
fplot = normsig.poslt1(X(:,exampleRoiIdx));
% strips(fplot)
fplot = bsxfun(@plus, fplot, cumsum(ones(1,nExample)));
hFig = figure;
plot(t,fplot); xlim([t(1) t(end)]); ylim([.9 nExample+1]);
title('Example ROI Traces'), xlabel('time (seconds)');
% set(gca, 'FontSize', 12, 'FontWeight', 'bold')
print(gcf,fullfile(figDir,get(get(gca,'Title'), 'String')), '-dpng')

%% GET LICK NOISE
lick = zeros(size(X,1),1);
lick(bhv.frameidx.alllicks) = 1;

%% SHORTER TRIAL LENGTH SOUND TRIGGERED
trialLength = 6*20;
ft6 = zeros(trialLength, nTrial, nRoi);
ftLick = zeros(trialLength, nTrial, nRoi);
soundTriggeredLick = zeros(trialLength, nTrial);
lickTriggeredLick = zeros(trialLength, nTrial);
for kRoi = 1:nRoi
   for kTrial=1:nTrial
	  idx =bhv.frameidx.alltrials(kTrial)-20;
	  if idx <= 0 || (idx+trialLength-1) > size(X,1)
		 continue
	  end
	  ft6(:,kTrial, kRoi) = X( idx:(idx+trialLength-1), kRoi);
	  % GET INDICES OF FIRST LICK AFTER SOUND (sound onset = trial onset)
	  idxLick = bhv.frameidx.alllicks(find(bhv.frameidx.alllicks > (idx+20), 1, 'first')) - 20;
	  if isempty(idxLick)
		 continue
	  end
	  ftLick(:,kTrial, kRoi) = X( idxLick:(idxLick+trialLength-1), kRoi);
	  soundTriggeredLick(:,kTrial) = lick(idx:(idx+trialLength-1));
	  lickTriggeredLick(:,kTrial) = lick(idxLick:(idxLick+trialLength-1));
   end
   k=kRoi;
   if any(k==exampleRoiIdx)
	  ex.soundtrig.long = ft6(:,bhv.trialidx.long,k);
	  ex.soundtrig.short = ft6(:,bhv.trialidx.short,k);
	  ex.soundtrig.longovershort = cat(2, ex.soundtrig.long, ex.soundtrig.short);
	  lickoverlay.long = soundTriggeredLick(:, bhv.trialidx.long);
	  lickoverlay.short = soundTriggeredLick(:, bhv.trialidx.short);
	  im = cat(3,...
		 .6*cat(2, lickoverlay.long, zeros(size(lickoverlay.short)))',...
		 .8*cat(2, zeros(size(lickoverlay.long)), lickoverlay.short )',...
		 normsig.poslt1(ex.soundtrig.longovershort)');
	  hIm = image(im, 'XData', -1:(1/20):5 );
	  title(sprintf('Tone-Triggered Trace with Licks - LONG-TONE (green), SHORT-TONE (blue) - Example Neuron %i', k))
	  set(gca,...
		 'YTick',[],...
		 'Position',[0 .05 1 .95])
	  % 	   th = annotation('textbox', 'Position',[.01 0 .98 .05],...
	  % 		'String',sprintf('Tone-Triggered Trace with Licks - LONG-TONE (green), SHORT-TONE (blue) - Example Neuron %i', k));
	  print(gcf,fullfile(figDir,get(get(gca,'Title'), 'String')), '-dpng')
	  % 	  imagesc(-1:(1/20):5,[], ft6(:,:,k))
	  % 	  title(sprintf('First-Lick-Triggered Trace - ALL TRIALS - Example Neuron %i', k))
	  % 	  xlabel('Time - 0 = tone onset'), ylabel('Trial')
	  % 	  set(gca, 'FontSize', 12, 'FontWeight', 'bold')
	  % 	  print(gcf,fullfile(figDir,get(get(gca,'Title'), 'String')), '-dpng')
	  subplot(2,1,1)
	  imagesc(-1:(1/20):5,[], normsig.z(squeeze(ft6( :, bhv.trialidx.long, k)))')
	  title( 'LONG-TONE TRIALS')
	  xlabel('Time - 0 = tone onset'), ylabel('Trial')
	  subplot(2,1,2)
	  imagesc(-1:(1/20):5,[], normsig.z(squeeze(ft6(:, bhv.trialidx.short, k)))')
	  title('SHORT-TONE TRIALS')
	  xlabel('Time - 0 = tone onset'), ylabel('Trial')
	  annotation('textbox', 'Position',[.01 0 .98 .05],...
		 'String', sprintf('Tone-Triggered Trace - SHORT-TONE TRIALS - Example Neuron %i', k));
	  print(gcf,fullfile(figDir, sprintf('Tone-Triggered Trace Example Neuron %i', k)), '-dpng')
	  clf
   end
end
t_ft6 = -.95:.05:(trialLength/20-1); %TODO
% trialRange = range(ft6,1);
% trialStd = nanstd(ft6,1);
% ft6 = bsxfun( @rdivide, bsxfun(@minus, ft6, mean(ft6,1)), trialStd);
ft6 = normsig.z(ft6);

%% SOUND-EVOKED CALCIUM RESPONSE RATIO
for boxfiltsize = 0:5:20
   for k=0:4
	  prepostResponseWindow = .25 * (2^k);
	  ser = ...
		 squeeze(nanmean(ft6(t_ft6 > 0 & t_ft6 <= prepostResponseWindow, : , :), 1)) ...
		 ./ squeeze(nanmean(ft6(t_ft6 <= 0 & t_ft6 > -prepostResponseWindow, : , :), 1));
	  ser = sqrt(abs(ser)).*sign(ser);
	  if boxfiltsize > 0
		 ser = filtfilt(ones(boxfiltsize-1,1)/(2*boxfiltsize), 1/(2*boxfiltsize), ser);
	  end
	  soundEvokedResponse.short = ser(bhv.trialidx.short,:);
	  soundEvokedResponse.long = ser(bhv.trialidx.long,:);
	  serMedian = median(ser(:));
	  serStdNonoutlier = nanstd(ser(abs(ser(:))<3*nanstd(ser(:))));
	  serClim = serMedian + 2.*[-serStdNonoutlier, serStdNonoutlier];
	  subplot(2,1,1);
	  imagesc(soundEvokedResponse.long', serClim), ylabel('ROI'), xlabel('Trial')
	  title( 'LONG TONE')
	  colorbar
	  subplot(2,1,2);
	  imagesc(soundEvokedResponse.short', serClim), ylabel('ROI'), xlabel('Trial')
	  title('SHORT TONE')
	  colorbar
	  annotation('textbox','Position',[.01 0 .98 .05],'String',...
		 sprintf('Sound-Evoked Response (%g sec response window, %i trial moving-average)',prepostResponseWindow, boxfiltsize));
	  figname = sprintf('Sound-Evoked Ca Response (%g sec response-window, %i trial moving-average)',prepostResponseWindow, boxfiltsize);
	  figname(strfind(figname,'.')) = '_';
	  print(gcf,fullfile(figDir,figname), '-dpng')
	  clf
   end
end

trialTrigAvg = squeeze(nanmean(ft6,2));
shortTrigAvg = squeeze(nanmean(ft6(:,bhv.trialidx.short,:),2));
longTrigAvg = squeeze(nanmean(ft6(:,bhv.trialidx.long,:),2));
diffTrigAvg = longTrigAvg - shortTrigAvg;
% BOTH
[~,trialTrigSort] = sort(trialTrigAvg(21,:));
subplot(2,2,1)
imagesc(-1:(1/20):5,[],trialTrigAvg(:, trialTrigSort)');
title('BOTH Sounds');
xlabel('Time - 0 = sound onset')
ylabel('Neuron')
% SHORT
% [~,trialTrigSort] = sort(trialTrigAvg(21,:));
subplot(2,2,2)
imagesc(-1:(1/20):5,[],shortTrigAvg(:, trialTrigSort)');
title('SHORT');
xlabel('Time - 0 = sound onset')
ylabel('Neuron')
% LONG
% [~,trialTrigSort] = sort(trialTrigAvg(21,:));
subplot(2,2,3)
imagesc(-1:(1/20):5,[],longTrigAvg(:, trialTrigSort)');
title('LONG');
xlabel('Time - 0 = sound onset')
ylabel('Neuron')
% DIFFERENCE
subplot(2,2,4)
imagesc(-1:(1/20):5,[],diffTrigAvg(:, trialTrigSort)');
title('DIFFERENCE');
xlabel('Time - 0 = sound onset')
ylabel('Neuron')
annotation('textbox','Position',[.01 0 .98 .05],'String','Trial-Triggered Mean (normalized)');
print(gcf,fullfile(figDir,'Trial-Triggered Mean'), '-dpng')
clf

%% PLOT BEHAVIOR (LICKS)
subplot(3,1,1)
imagesc(-1:(1/20):5,[],lickTriggeredLick');
title('BOTH TONES');
xlabel('Time - 0 = first lick after tone onset')
ylabel('Trial')
subplot(3,1,2)
imagesc(-1:(1/20):5,[],lickTriggeredLick(:,bhv.trialidx.long)');
title('LONG TONE')
xlabel('Time - 0 = first lick after tone onset')
ylabel('Trial')
subplot(3,1,3)
imagesc(-1:(1/20):5,[],lickTriggeredLick(:,bhv.trialidx.short)');
title('SHORT TONE')
xlabel('Time - 0 = first lick after tone onset')
ylabel('Trial')
annotation('textbox','Position',[.01 0 .98 .05],'String','Lick-Triggered-Lick');
print(gcf,fullfile(figDir,'Lick-Triggered-Lick'), '-dpng')
clf
subplot(3,1,1)
imagesc(-1:(1/20):5,[],soundTriggeredLick');
title('BOTH TONES');
xlabel('Time - 0 = tone onset')
ylabel('Trial')
subplot(3,1,2)
imagesc(-1:(1/20):5,[],soundTriggeredLick(:,bhv.trialidx.long)');
title('LONG TONE')
xlabel('Time - 0 = tone onset')
ylabel('Trial')
subplot(3,1,3)
imagesc(-1:(1/20):5,[],soundTriggeredLick(:,bhv.trialidx.short)');
title('SHORT TONE')
xlabel('Time - 0 = tone onset')
ylabel('Trial')
annotation('textbox','Position',[.01 0 .98 .05],'String','Sound-Triggered-Lick');
print(gcf,fullfile(figDir,'Sound-Triggered-Lick'), '-dpng')
clf

%% LICK TRIGGERED
ftLickMean = squeeze(nanmean(ftLick,2));
shortlickAvg = squeeze(nanmean(ftLick(:,bhv.trialidx.short,:),2));
longlickAvg = squeeze(nanmean(ftLick(:,bhv.trialidx.long,:),2));
diffLickAvg = longlickAvg - shortlickAvg;
% NORMALIZATION
ftLickMeanNorm = bsxfun(@rdivide, bsxfun(@minus, ftLickMean,  nanmean(ftLickMean,1)), nanstd(ftLickMean,1, 1));
shortlickMeanNorm = bsxfun(@rdivide, bsxfun(@minus, shortlickAvg,  nanmean(shortlickAvg,1)), nanstd(shortlickAvg,1, 1));
longlickMeanNorm = bsxfun(@rdivide, bsxfun(@minus, longlickAvg,  nanmean(longlickAvg,1)), nanstd(longlickAvg,1, 1));
diffLickMeanNorm = bsxfun(@rdivide, bsxfun(@minus, diffLickAvg,  nanmean(diffLickAvg,1)), nanstd(diffLickAvg,1, 1));
% BOTH
[~,lickTrigSort] = sort(ftLickMeanNorm(21,:));
subplot(2,2,1)
imagesc(-1:(1/20):5,[],ftLickMeanNorm(1:(6*20), lickTrigSort)');
title('Lick-Triggered Mean - BOTH (postnorm)');
xlabel('time')
ylabel('Neuron')
% SHORT
% [~,trialTrigSort] = sort(trialTrigAvg(21,:));
subplot(2,2,2)
imagesc(-1:(1/20):5,[],shortlickMeanNorm(1:(6*20), lickTrigSort)');
title('Lick-Triggered Mean - SHORT (postnorm)');
xlabel('time')
ylabel('Neuron')
% LONG
% [~,trialTrigSort] = sort(trialTrigAvg(21,:));
subplot(2,2,3)
imagesc(-1:(1/20):5,[],longlickMeanNorm(1:(6*20), lickTrigSort)');
title('Lick-Triggered Mean - LONG (postnorm)');
xlabel('time')
ylabel('Neuron')
% DIFFERENCE
subplot(2,2,4)
imagesc(-1:(1/20):5,[],diffLickMeanNorm(1:(6*20), lickTrigSort)');
title('Lick-Triggered Mean - DIFFERENCE (postnorm)');
xlabel('time')
ylabel('Neuron')

print(gcf,fullfile(figDir,'Lick-Triggered-Mean'), '-dpng')
clf

%% LICK-TRIGGERED (PRE-NORMALIZED) WITH EXAMPLE ROI ALL TRIALS
ftLickZ = normsig.z(ftLick);
firstLickTrace = zeros(nTrial,120,nRoi);
% clf
for k = 1:nRoi
   firstLickTrace(:,:,k) = normsig.z(squeeze(ftLickZ(:,:,k)))';
   if any(k==exampleRoiIdx)
	  % 	  imagesc(-1:(1/20):5,[], firstLickTrace(:,:,k))
	  % 	  title(sprintf('First-Lick-Triggered Trace - ALL TRIALS - Example Neuron #%i ',k))
	  % 	  xlabel('Time - 0 = first lick after tone onset'), ylabel('Trial')
	  % 	  set(gca, 'FontSize', 12, 'FontWeight', 'bold')
	  % 	  print(gcf,fullfile(figDir,get(get(gca,'Title'), 'String')), '-dpng')
	  subplot(2,1,1)
	  imagesc(-1:(1/20):5,[], firstLickTrace( bhv.trialidx.long, :, k))
	  title('LONG-TONE TRIALS')
	  xlabel('Time - 0 = first lick after tone onset'), ylabel('Trial')
	  subplot(2,1,2)
	  imagesc(-1:(1/20):5,[], firstLickTrace( bhv.trialidx.short, :, k))
	  title('SHORT-TONE TRIALS')
	  xlabel('Time - 0 = first lick after tone onset'), ylabel('Trial')
	  annotation('textbox','Position',[.01 0 .98 .05],'String',sprintf('First-Lick-Triggered Trace: Example Neuron %i', k));
	  print(gcf,fullfile(figDir,sprintf('First-Lick-Triggered Trace - Example Neuron %i', k)), '-dpng')
   end
end
firstLickTrialNormedAvg = squeeze(nanmean(firstLickTrace,1))';
shortlickTrialNormedAvg = squeeze(nanmean(firstLickTrace(bhv.trialidx.short,:,:),1))';
longlickTrialNormedAvg = squeeze(nanmean(firstLickTrace(bhv.trialidx.long,:,:),1))';
diffLickTrialNormedAvg = longlickTrialNormedAvg - shortlickTrialNormedAvg;
clf
subplot(2,2,1)
imagesc(-1:(1/20):5,[], firstLickTrialNormedAvg(lickTrigSort,:));
title('First-Lick-Triggered Traces - BOTH TONES')
xlabel('Time - 0 = first lick after tone onset')
ylabel('Neuron')
subplot(2,2,2)
imagesc(-1:(1/20):5,[], shortlickTrialNormedAvg(lickTrigSort,:));
title('First-Lick-Triggered Traces - SHORT TONE')
xlabel('Time - 0 = first lick after tone onset')
ylabel('Neuron')
subplot(2,2,3)
imagesc(-1:(1/20):5,[], longlickTrialNormedAvg(lickTrigSort,:));
title('First-Lick-Triggered Traces - LONG TONE)')
xlabel('Time - 0 = first lick after tone onset')
ylabel('Neuron')
subplot(2,2,4)
imagesc(-1:(1/20):5,[], diffLickTrialNormedAvg(lickTrigSort,:));
title('First-Lick-Triggered Traces - DIFFERENCE')
xlabel('Time - 0 = first lick after tone onset')
ylabel('Neuron')

print(gcf,fullfile(figDir,'Lick-Triggered-Mean (Pre-Normalized)'), '-dpng')
close all



% set(get(gcf,'Children'), 'FontSize', 12, 'FontWeight', 'bold')





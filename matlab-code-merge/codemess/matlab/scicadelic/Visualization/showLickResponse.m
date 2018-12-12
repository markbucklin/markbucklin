function showLickResponse()
normsig = normfunctions();
figDir = [pwd,filesep,'Figures'];
if ~isdir(figDir)
   mkdir(figDir)
end

%% LOAD ROI DATA (R)
file.roi = dir([pwd,'\Re_Processed_ROIs_*.mat']);
[~,idx] = max(datenum({file.roi.date}));
load(file.roi(idx).name);
nRoi = numel(R);
X = single([R.Trace]);
% X = normsig.zmlt1(X);
for k=1:nRoi
   R(k).Trace = X(:,k);
end

%% LOAD TRIAL AND LICK DATA (loadBehaviorData)
% trial = importTrialData();
% nTrial = min(200, size(trial,1));
% trial = trial(1:nTrial,:);
% try
%    lickdata = importLickData();
% catch
%    %    lickdata = importLickDataDevalue();
%    % getthislickdata
%    load('lickdata.mat')
% end
% LOAD VIDEO TIMESTAMP INFO
% file.vid = dir('Processed_VideoFiles*');
% [~,idx] = max(datenum({file.vid.date}));
% load(file.vid(idx).name);
% info = getInfo(allVidFiles);
% t = cat(1,info.time);

% LOAD BEHAVIOR DATA (including trial structure)
bhv = loadBehaviorData();
t = bhv.t; %TODO: FIX MISSING FRAMES (interpolate?
nTrial = min(200, size(bhv.frameidx.alltrials,1));
nFrames = size(X,1);

% FIND FRAME INDICES ALIGNED WITH TRIAL STARTS
% bhv.trialidx.short = find(trial.stim == min(trial.stim));
% bhv.trialidx.long = find(trial.stim == max(trial.stim));
% bhv.trialidx.longovershort = cat(1,bhv.trialidx.long, bhv.trialidx.short);
% bhv.frameidx.alltrials = find(any(bsxfun(@ge, t, trial.tstart') & bsxfun(@lt, circshift(t,1), trial.tstart'),2));
% bhv.frameidx.shortTrial =bhv.frameidx.alltrials(bhv.trialidx.short);
% bhv.frameidx.longTrial = bhv.frameidx.alltrials(bhv.trialidx.long);

% FIND FRAME INDICES ALIGNED WITH LICKS
% bhv.frameidx.alllicks = find(any(bsxfun(@ge, t, lickdata.tlick') & bsxfun(@lt, circshift(t,1), lickdata.tlick'),2));
% bhv.frameidx.shortlick = bhv.frameidx.alllicks(bhv.trialidx.short);
% bhv.frameidx.longLick = bhv.frameidx.alllicks(bhv.trialidx.long);

%% CONSTRUCT BINARY BEHAVIOR STRUCTURE (SYNC TO VIDEO FRAMES)
M = size(X,1);
nLicks = numel(bhv.frameidx.alllicks);
% clear bhv
% bhv.licklogical.lick = false(M,1);
% bhv.licklogical.lick(bhv.frameidx.alllicks) = true;
% bhv.licklogical.soundlick = false(M,1);
% bhv.licklogical.soundlick(bhv.frameidx.alllicks) = logical(lickdata.duringsound(1:nLicks));
% bhv.licklogical.windowlick = false(M,1);
% bhv.licklogical.windowlick(bhv.frameidx.alllicks) = logical(lickdata.duringwindow(1:nLicks));
% bhv.licklogical.itilick = false(M,1);
% bhv.licklogical.itilick(bhv.frameidx.alllicks) = logical(lickdata.duringiti(1:nLicks));
% bhv.licklogical.shortlick = false(M,1);
% bhv.licklogical.shortlick(bhv.frameidx.alllicks) = lickdata.stim(1:nLicks) == min(lickdata.stim(:));

%% SHUFFLED RANDOM LICKS
[~,idx] = sort(rand(M,1));
bhv.licklogical.randomlick = bhv.licklogical.lick(idx);
nTrials = numel(bhv.frameidx.alltrials);
fld = fields(bhv.licklogical);
fld = fld(structfun(@islogical, bhv.licklogical));
bhv.licklogical.first.randomlick = false(M,1);
for k=1:nTrials
   trialBin = false(M,1);
   if k<nTrials
	  trialBin(bhv.frameidx.alltrials(k):bhv.frameidx.alltrials(k+1)) = true;
   else
	  trialBin(bhv.frameidx.alltrials(k):end) = true;
   end
   bhv.licklogical.first.randomlick(find(bhv.licklogical.randomlick & trialBin, 1, 'first')) = true;
end
% bhv.licklogical.longlick = false(M,1);
% bhv.licklogical.longlick(bhv.frameidx.alllicks) = lickdata.stim(1:nLicks) == max(lickdata.stim(:));
% bhv.licklogical.randomlick = false(M,1);
% poissonIdx = cumsum(ceil(randn(sum(bhv.licklogical.windowlick(:)),1).*var(diff(find(bhv.licklogical.lick))) + mean(diff(find(bhv.licklogical.lick)))));
% poissonIdx = poissonIdx(poissonIdx <= M & poissonIdx >0);
% bhv.licklogical.randomlick(poissonIdx) = true;

%% FIRST-LICK-TRIGGERED CALCIUM RESPONSE (RAW)
shoulder.pre = 2;
shoulder.post = 10;
rspIdx = round(-shoulder.pre*20:shoulder.post*20);
first250idx = find(rspIdx > 0 & rspIdx <= .25*20);
lickresponse.raw.subscriptname = {'rspIdx', '1:nTrials', '1:nRoi'};
for fn = 1:numel(fld)
   lickresponse.raw.(fld{fn}) = NaN(numel(rspIdx), nTrials, nRoi);
end
for k=1:nTrials
   idx = bhv.frameidx.firstlick(k) + rspIdx;
   idx(idx < 1) = 1;
   idx(idx > nFrames) = nFrames;
   if any(isnan(idx))
	  continue
   end
   for fn = 1:numel(fld)
	  try
		 if any(bhv.licklogical.first.(fld{fn})(idx))
			idxshift = find(bhv.licklogical.first.(fld{fn})(idx), 1, 'first') - 1 + rspIdx(1);
			% 			if all((idx+idxshift) <= nFrames) && all((idx+idxshift) > 0)
			% 			   lickresponse.raw.(fld{fn})(:,k,:) = X(idx+idxshift, :);
			% 			   lickresponse.raw.trialmean.(fld{fn}) = squeeze(nanmean(lickresponse.raw.(fld{fn}), 2))';
			% 			else
			valididx = idx+idxshift;
			% 			   overidx = valididx(valididx > nFrames);
			invalididx = (valididx > nFrames) | (valididx < 1);
			valididx = valididx(~invalididx);			
			lickresponse.raw.(fld{fn})(~invalididx,k,:) = X(valididx, :);
			% 			   lickresponse.raw.(fld{fn})(numel(valididx)+1:end,k,:) = NaN;
			lickresponse.raw.trialmean.(fld{fn}) = squeeze(nanmean(lickresponse.raw.(fld{fn}), 2))';
			% 			end
		 else
			lickresponse.raw.(fld{fn})(:,k,:) = NaN;
			lickresponse.raw.trialmean.(fld{fn}) = squeeze(nanmean(lickresponse.raw.(fld{fn}), 2))';
		 end
	  catch me
		 keyboard
	  end
   end
end
%%
for fn = 1:numel(fld)
   try
	  [~, lickresponse.raw.trialmean.sortedby.(fld{fn})] = ...
		 sort(nanmean(lickresponse.raw.trialmean.(fld{fn})(:,first250idx),2) );
	  idx = lickresponse.raw.trialmean.sortedby.(fld{fn});
	  subplot(3,3,fn)
	  imagesc(rspIdx/20, [], lickresponse.raw.trialmean.(fld{fn})(idx,:))
	  title(sprintf(' %s',upper(fld{fn})));
	  xlabel('Time (s) centered on first lick')
	  ylabel('ROI')
	  set(gca,'YTick',[]);
   catch me	  
	  keyboard
   end
end
annotation('textbox', 'Position',[.01 0 .98 .05],...
   'String', 'RAW Ca-Response Aligned to First Lick in Various Trial Phases');

%% FIRST-LICK-TRIGGERED CALCIUM RESPONSE (NORMALIZED TO TRIAL MEAN AND STD)
lickresponse.normalized.trialmean.subscriptname = {'1:nRoi','rspIdx'};
for fn = 1:numel(fld)
   lickresponse.normalized.(fld{fn}) = normsig.z(lickresponse.raw.(fld{fn}));
   lickresponse.normalized.trialmean.(fld{fn}) = squeeze(nanmean(lickresponse.normalized.(fld{fn}), 2))';
   [~, lickresponse.normalized.trialmean.sortedby.(fld{fn})] = ...
	  sort(nanmean(lickresponse.normalized.trialmean.(fld{fn})(:,first250idx),2) );
   idx = lickresponse.normalized.trialmean.sortedby.(fld{fn});
   subplot(3,3,fn)
   set(gca,'YTick',[]);
   set(gca,'XTick',[0]);
   imagesc(rspIdx/20, [], lickresponse.normalized.trialmean.(fld{fn})(idx,:))
   title(sprintf('%s',upper(fld{fn})));
   %    xlabel('Time (s) centered on first lick')
   %    ylabel('ROI')
end
annotation('textbox', 'Position',[.01 0 .98 .05],...
   'String', 'NORMALIZED Ca-Response Aligned to First Lick in Various Trial Phases');
print(gcf,fullfile(figDir,'Normalized Ca-Response Aligned to First Lick '),'-dpng')
clf

%% FIRST-LICK-TRIGGERED CALCIUM RESPONSE
% shoulder.pre = 2;
% shoulder.post = 10;
% rspIdx = round(-shoulder.pre*20:shoulder.post*20);
% lickresponse.subscriptname = {'rspIdx', '1:nTrials', '1:nRoi'};
% for fn = 1:numel(fld)
%    lickresponse.(fld{fn}) = zeros(numel(rspIdx), nTrials, nRoi);
% end
% for k=1:nTrials
%    idx = bhv.frameidx.alltrials(k) + rspIdx;
%    if any(idx < 1) || any(idx > size(X,1))
% 	  continue
%    end
%    for fn = 1:numel(fld)
% 	  if any(bhv.licklogical.first.(fld{fn})(idx))
% 		 lickresponse.(fld{fn})(:,k,:) = X(idx, :);
% 	  end
%    end
% end
% first250idx = find(rspIdx > 0 & rspIdx <= .25*20);
% lickresponse.normalized.mean.subscriptname = {'1:nRoi','rspIdx'};
% for fn = 1:numel(fld)
%    lickresponse.normalized.(fld{fn}) = normsig.z(lickresponse.(fld{fn}));
%    lickresponse.normalized.mean.(fld{fn}) = squeeze(nanmean(lickresponse.normalized.(fld{fn}), 2))';
%    [~, lickresponse.normalized.mean.sortedby.(fld{fn})] = ...
% 	  sort(mean(lickresponse.normalized.mean.(fld{fn})(:,first250idx),2) );
%    % PRINT LICK RESPONSE
%    idx = lickresponse.normalized.mean.sortedby.(fld{fn});
%    subplot(3,2,fn)
%    imagesc(rspIdx/20, [], lickresponse.normalized.mean.(fld{fn})(idx,:))
%    title(fld{fn})
%    xlabel('Time (s) centered on first lick')
%    ylabel('Neuron')
% end
% print(gcf,fullfile(figDir,'First Lick Trig Avg comparison '),'-dpng')
% clf

%% RESPONSE COMPARISON
% idx = lickresponse.normalized.mean.sortedby.soundlick;
% imcomp = imfuse( ...
%    lickresponse.normalized.mean.soundlick(idx,:),...
%    lickresponse.normalized.mean.itilick(idx,:),...
%    'ColorChannels', 'red-cyan');
% hIm = image(imcomp, 'XData', rspIdx/20);
% xlabel('Time;  Aligned to First Lick After Sound (RED), and First Lick of ITI (CYAN)'), ylabel('Neuron')
% title('Pre-Normalized Average Lick-Triggered Response')
% set(gca, 'FontSize', 10, 'FontWeight', 'bold')
% colormap jet
% print(gcf,fullfile(figDir,'Pre-Normalized Average Lick-Triggered Response '),'-dpng')
% clf

%% GET LICK NOISE
% lick = double(bhv.frameidx.alllicks);
% df = diff(double([X(1,:) ; X]), 1,1);
% fNoise = zeros(size(X));
% for k=1:size(df,2)
%    fNoise(:,k) = conv(lick, df(:,k), 'same');
% end
%
% ltLag = 80;
% ltMean = zeros(2*ltLag+1,nRoi);
% for kRoi = 1:nRoi
%    for k=1:(ltLag*2+1)
% 	  tau=k-ltLag+1;
% 	  lickIdx = bhv.frameidx.alllicks+tau;
% 	  lickIdx = lickIdx(lickIdx>=1 & lickIdx <=size(X,1));
% 	  ltMean(k,kRoi) = mean(X(max(1,lickIdx),kRoi), 1);
%    end
% end
% ltMeanNorm = bsxfun(@rdivide, bsxfun(@minus, ltMean,  mean(ltMean,1)), std(ltMean,1,1));
% [~,ltmnIdx] = sort(max(ltMeanNorm(ltLag-5:ltLag+5,:),[],1));
% clf, imagesc(ltMeanNorm(:,ltmnIdx)')
% title('Lick-Triggered Mean for Each Neuron (normalized and sorted post-average)')
% h = get(gca,'Children');
% h.XData = -80/20 : 1/20 : 80/20;
% set(gca, 'XLim',[ -80/20 80/20])
% xlabel('Time (s) centered on lick')
% ylabel('Neuron')
% print(gcf,fullfile(figDir,get(get(gca,'Title'), 'String')), '-dpng')
% clf, surf(ltMeanNorm(:,ltmnIdx), 'FaceColor','interp','FaceLighting','phong','EdgeColor','none'); axis tight, camlight left
% h = get(gca,'Children');
% h(2).YData = -80/20 : 1/20 : 80/20;
% ylabel('Time (s) centered on lick')
% xlabel('Neuron')
% colormap hot
% title('Lick-Triggered Mean Surface Plot (normalized and sorted post-average)')
% print(gcf,fullfile(figDir,get(get(gca,'Title'), 'String')), '-dpng')
% clf
% lickImpulse = zeros(size(X,1),1);
% lickImpulse(bhv.frameidx.alllicks) = 1;
% ltSig = zeros(numel(lickImpulse), nRoi);
% for kRoi = 1:nRoi
%    ltSig(:,kRoi) = conv(lickImpulse, ltMeanNorm(:,kRoi), 'same');
% end


%
% tau = t(1:120);
%  X = bsxfun( @rdivide, bsxfun( @minus, X, min(X,[],1)), range(X,1));
% stimKernel = exp(-(2*tau)/sqrt(2) - exp(-(15*tau)/(sqrt(2))));
% stimTrace.long = conv(stimTrace.long, stimKernel);
% stimTrace.long = stimTrace.long(1:numel(t));
% stimTrace.short = conv(stimTrace.short, stimKernel);
% stimTrace.short = stimTrace.short(1:numel(t));
% skFilt.long = squeeze(filter(stimTrace.long, 1, bsxfun(@minus, X , mean(X,1))));
% skFilt.short = squeeze(filter(stimTrace.short, 1, bsxfun(@minus, X , mean(X,1))));

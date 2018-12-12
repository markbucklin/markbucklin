% md = loadMultiDayRoi_Reprocessed

%% GET XCORR
% xc = cat(1, md(1).procsum.xc)
for k=1:numel(md)
   try
	  R = md(k).roi;
	  bhv = md(k).bhv;
	  X = [R.RawTrace];
	  nRoi = numel(R);
	  nFrames = size(X,1);
	  behaviorSignal =  single([bhv.soundlogical.all,...
		 bhv.soundlogical.firstsecond,...
		 bhv.soundlogical.long,...
		 bhv.soundlogical.short]);
	  %    lickSignal = single(bhv.licklogical.first.soundlick);
	  lickSignal = single(bhv.licklogical.lick);
	  firstLickSignal = single(bhv.licklogical.first.soundlick);
	  maxlag = 20;
	  [~,lags] = xcorr(X(:,1), behaviorSignal(:,1), maxlag);
	  lags = lags/20;
	  Csound = [];
	  Cfirstsecond = [];
	  Clong = [];
	  Cshort = [];
	  Click = [];
	  Cfirstlick = [];
	  parfor kx = 1:nRoi
		 Csound(:,kx) = xcorr(X(:,kx), behaviorSignal(:,1), maxlag);
		 Cfirstsecond(:,kx) = xcorr(X(:,kx), behaviorSignal(:,2), maxlag);
		 Clong(:,kx) = xcorr(X(:,kx), behaviorSignal(:,3), maxlag);
		 Cshort(:,kx) = xcorr(X(:,kx), behaviorSignal(:,4), maxlag);
		 Click(:,kx) = xcorr(X(:,kx), lickSignal, maxlag);
		 Cfirstlick(:,kx) = xcorr(X(:,kx), firstLickSignal, maxlag);
		 % 	  Csound(:,kx) = max(xcorr(X(:,kx), behaviorSignal(:,1), maxlag));
		 % 	  Cfirstsecond(:,kx) = max(xcorr(X(:,kx), behaviorSignal(:,2), maxlag));
		 % 	  Clong(:,kx) = max(xcorr(X(:,kx), behaviorSignal(:,3), maxlag));
		 % 	  Cshort(:,kx) = max(xcorr(X(:,kx), behaviorSignal(:,4), maxlag));
		 % 	  Click(:,kx) = max(xcorr(X(:,kx), lickSignal, maxlag));
		 % 	  Cfirstlick(:,kx) = max(xcorr(X(:,kx), firstLickSignal, maxlag));
	  end
	  [C(k).sound.max, idx] = max(Csound,[],1);
	  C(k).sound.lag = lags(idx);
	  [C(k).firstsecond.max, idx] = max(Cfirstsecond,[],1);
	  C(k).firstsecond.lag = lags(idx);
	  [C(k).long.max, idx] = max(Clong,[],1);
	  C(k).long.lag = lags(idx);
	  [C(k).short.max, idx] = max(Cshort,[],1);
	  C(k).short.lag = lags(idx);
	  [C(k).lick.max, idx] = max(Click,[],1);
	  C(k).lick.lag = lags(idx);
	  [C(k).firstlick.max, idx] = max(Cfirstlick,[],1);
	  C(k).firstlick.lag = lags(idx);
	  
	  nStd = 1.5;
	  Rsig.sound = R(C(k).sound.max > mean(C(k).sound.max)+nStd*std(C(k).sound.max));
	  Rsig.long = R(C(k).long.max > mean(C(k).long.max)+nStd*std(C(k).long.max));
	  Rsig.short = R(C(k).short.max > mean(C(k).short.max)+nStd*std(C(k).short.max));
	  Rsig.firstsecond = R(C(k).firstsecond.max > mean(C(k).firstsecond.max)+nStd*std(C(k).firstsecond.max));
	  Rsig.lick = R(C(k).lick.max > mean(C(k).lick.max)+nStd*std(C(k).lick.max));
	  Rsig.firstlick = R(C(k).firstlick.max > mean(C(k).firstlick.max)+nStd*std(C(k).firstlick.max));
	  
	  set(R,'Color',[.1 .1 .1])
	  for ksig = 1:numel(Rsig.sound)
		 Rsig.sound(ksig).Color(3) = .9;
	  end
	  for ksig = 1:numel(Rsig.long)
		 Rsig.long(ksig).Color(1) = .9;
	  end
	  for ksig = 1:numel(Rsig.short)
		 Rsig.short(ksig).Color(2) = .9;
	  end
	  h = show(R);
	  drawnow
	  
	  
	  %    xcor(k).rho = rho;
	  %    xcor(k).pval = pval;
	  %    xcor(k).signif = signif;
	  C(k).sigroi = Rsig;
	  C(k).frame = getframe(h.fig);
	  C(k).h = h;
	  close(h.fig)
   catch me
	  keyboard
   end
   %    % EVALUATE TIME DEPENDENDENCE
   %    for kShuf = 1:5
   % 	  % SHUFFLE ROI SIGNAL
   % 	  pcorshuf(k,kShuf).xshuf.shift = fix( nFrames .* (rand(nRoi,1) - 1/2) );
   % 	  xshuf = X;
   % 	  for kx = 1:nRoi
   % 		 xshuf(:,kx) = circshift(xshuf(:,kx), pcorshuf(k,kShuf).xshuf.shift(kx));
   % 	  end
   % 	  [rho,pval] = partialcorr(xshuf, behaviorSignal, lickSignal);
   % 	  pcorshuf(k,kShuf).xshuf.rho = rho;
   % 	  pcorshuf(k,kShuf).xshuf.pval = pval;
   % 	  % SHUFFLE BEHAVIOR SIGNAL
   % 	  pcorshuf(k,kShuf).bhvshuf.shift = fix( nFrames * (rand - 1/2));
   % 	  bhvshuf = circshift(behaviorSignal, pcorshuf(k,kShuf).bhvshuf.shift);
   % 	  [rho,pval] = partialcorr(X, bhvshuf, lickSignal);
   % 	  pcorshuf(k,kShuf).bhvshuf.rho = rho;
   % 	  pcorshuf(k,kShuf).bhvshuf.pval = pval;
   % 	  % SHUFFLE LICK SIGNAL
   % 	  pcorshuf(k,kShuf).lickshuf.shift = fix( nFrames * (rand - 1/2));
   % 	  lickshuf = circshift(lickSignal, pcorshuf(k,kShuf).lickshuf.shift);
   % 	  [rho,pval] = partialcorr(X, behaviorSignal, lickshuf);
   % 	  pcorshuf(k,kShuf).lickshuf.rho = rho;
   % 	  pcorshuf(k,kShuf).lickshuf.pval = pval;
   %    end
   
   %    for kShuf = 1:5
   % 	  [~,pcorshuf(k,kShuf).idx] = sort(rand(numel(bhv.soundlogical.all),1));
   % 	  [rho,pval] = partialcorr(X, behaviorSignal(pcorshuf(k,kShuf).idx, :), lickSignal(pcorshuf(k,kShuf).idx, :));
   % 	  pcorshuf(k,kShuf).rho = rho;
   % 	  pcorshuf(k,kShuf).pval = pval;
   %    end
end
%
% histogram(C.firstsecond.max)
% hold on
% histogram(C.firstlick.max)
% legend('First Second', 'First Lick')
% title('Distribution of Cross Correlation with FIRST SECOND AND FIRST LICK after tone onset')
% histogram(C.firstsecond.max)
% hold on
% histogram(C.sound.max)
% legend('First 1 Second', 'First 6 Seconds')
% title('Distribution of Cross Correlation with FIRST 1 SECOND AND FIRST 6 SECONDS after tone onset')
% histogram(C.long.max)
% hold on
% histogram(C.short.max)
% histogram(C.sound.max)
% legend('Long Tone', 'Short Tone', 'Both Tones')
% title('Distribution of Cross Correlation with 6 Seconds Following LONG, SHORT, AND BOTH Ttone Onset')








roiframe = cat(1,C.frame);
imaqmontage(cat(4,roiframe.cdata))
ax = gca;
ax.DataAspectRatio = [1 1 1];
ax.Position = [0 0 1 1];
title(['Top Correlators  with LONG (Red),  SHORT (Green), and BOTH (Blue) Tones:',...
   'using XCORR function (maxlag 1-second)']);
%%
% figure;
%  histogram(pcorshuf(1,1).xshuf.rho(:,3)), hold on, histogram(pcorshuf(1,1).xshuf.rho(:,4))
% histogram(pcor(1).rho(:,3)), histogram(pcor(1).rho(:,4))
% figure
% scatterhist(pcorshuf(1,1).xshuf.rho(:,3), pcorshuf(1,1).xshuf.rho(:,4), '.');
% hold on
% scatterhist(pcor(1).rho(:,3), pcor(1).rho(:,4), '.');
% figure,
% scatter(C(1).pval(:,1), pcorshuf(1,1).xshuf.pval(:,1), 'Marker','.')
% hold on
% scatter(C(1).pval(:,1), pcorshuf(1,2).xshuf.pval(:,1), 'Marker','.')
% scatter(C(1).pval(:,1), pcorshuf(1,3).xshuf.pval(:,1), 'Marker','.')
% scatter(C(1).pval(:,1), pcorshuf(1,4).xshuf.pval(:,1), 'Marker','.')
% scatter(C(1).pval(:,1), pcorshuf(1,5).xshuf.pval(:,1), 'Marker','.')
% title('Partial Correlation Pvalue of Real-Data vs. Randomly Shifted CA-FLUORESCENCE')
% xlabel('Unshifted X P-Value')
% ylabel('Randomly-Shifted X P-Value')
%
% figure,
% scatter(C(1).pval(:,1), pcorshuf(1,1).bhvshuf.pval(:,1), 'Marker','.')
% hold on
% scatter(C(1).pval(:,1), pcorshuf(1,2).bhvshuf.pval(:,1), 'Marker','.')
% scatter(C(1).pval(:,1), pcorshuf(1,3).bhvshuf.pval(:,1), 'Marker','.')
% scatter(C(1).pval(:,1), pcorshuf(1,4).bhvshuf.pval(:,1), 'Marker','.')
% scatter(C(1).pval(:,1), pcorshuf(1,5).bhvshuf.pval(:,1), 'Marker','.')
% title('Partial Correlation Pvalue of Real-Data vs. Randomly Shifted SOUND-ONSET')
% xlabel('Unshifted X P-Value')
% ylabel('Randomly-Shifted Sound-Onset P-Value')
%
% figure,
% scatter(C(1).pval(:,1), pcorshuf(1,1).lickshuf.pval(:,1), 'Marker','.')
% hold on
% scatter(C(1).pval(:,1), pcorshuf(1,2).lickshuf.pval(:,1), 'Marker','.')
% scatter(C(1).pval(:,1), pcorshuf(1,3).lickshuf.pval(:,1), 'Marker','.')
% scatter(C(1).pval(:,1), pcorshuf(1,4).lickshuf.pval(:,1), 'Marker','.')
% scatter(C(1).pval(:,1), pcorshuf(1,5).lickshuf.pval(:,1), 'Marker','.')
% title('Partial Correlation Pvalue of Real-Data vs. Randomly Shifted LICK-TIMES')
% xlabel('Unshifted X P-Value')
% ylabel('Randomly-Shifted Lick P-Value')



%% SHOW PARTIALCORR
kDay=1;
t = md(kDay).bhv.t;

trialdata = zeros([1, numel(t), 3]);
% LONG TONE BACKGROUND
for kTrial = 1:numel(md(kDay).bhv.frameidx.longTrial)
   fOn = md(kDay).bhv.frameidx.longTrial(kTrial);
   fOff = fOn + 19;
   trialdata(:, fOn:fOff, 1) = .8;
end
% SHORT TONE BACKGROUND
for kTrial = 1:numel(md(kDay).bhv.frameidx.shortTrial)
   fOn = md(kDay).bhv.frameidx.shortTrial(kTrial);
   fOff = fOn + 19;
   trialdata(:, fOn:fOff, 2) = .8;
end
% ADD LICK
% trialdata(:, md(kDay).bhv.frameidx.allLicks, :) = repmat(shiftdim([0 0 0], -1), 1,numel(t),1);
% trialdata(:, md(kDay).bhv.frameidx.firstLick, :) = repmat(shiftdim([0 0 .4],-1), 1,numel(t),1);
% close
% nRoi = min(numel(topcor.long), numel(topcor.short));
figure
nRoi = min(structfun(@numel, C(2).sigroi));
hIm = image(t,[0 nRoi], trialdata, 'AlphaData', .1);
hAx = gca;
hold on
for kRoi = 1:nRoi;
   %       hLine(kRoi,1) = line(t, pnormalize(C(kDay).sigroi.sound(kRoi).Trace)+kRoi-1, 'Color', 'k');
   % 	  hLine(kRoi,2) = line(t, pnormalize(C(kDay).sigroi.firstsecond(kRoi).Trace)+kRoi-1, 'Color', 'b');
      hLine(kRoi,1) = line(t, pnormalize(C(kDay).sigroi.long(kRoi).Trace)+kRoi-1, 'Color', 'r');
      hLine(kRoi,2) = line(t, pnormalize(C(kDay).sigroi.short(kRoi).Trace)+kRoi-1, 'Color', 'g');
   try
% 	  hLine(kRoi,1) = line(t, pnormalize(C(kDay).sigroi.longonly(kRoi).Trace(1:numel(t)))+kRoi-1, 'Color', 'r');
% 	  hLine(kRoi,2) = line(t, pnormalize(C(kDay).sigroi.shortonly(kRoi).Trace(1:numel(t)))+kRoi-1, 'Color', 'g');
   catch me
   end
end
axis xy
ylim([0 nRoi+1]);

%%
x = C(kDay).sigroi.long(kRoi).Trace;
F = zeroShiftedWinMat(x,6*20);
tau = (1:6*20)/20;
figure, plot(tau, F(:,md(kDay).bhv.frameidx.longTrial),'Color',[1 0 0 .2])
hold on
plot(tau, mean(F(:,md(kDay).bhv.frameidx.longTrial),2),'Color',[1 0 0 1], 'LineWidth',2)

plot(tau, F(:,md(kDay).bhv.frameidx.shortTrial),'Color',[0 0 1 .2])
plot(tau, mean(F(:,md(kDay).bhv.frameidx.shortTrial),2),'Color',[0 0 1 1], 'LineWidth',2)

% plot(t, md(k).bhv.soundlogical.long, 'r');
% plot(t, md(k).bhv.soundlogical.short, 'g');

% ax.Backdrop.Face.ColorBinding = 'discrete'
% n = 0;
% for k=1:numel(md(k).bhv.frameidx.shortTrial)
%    n=n+1;
%    tsoundon = md(k).bhv.frameidx.shortTrial(k);
%    ax.Backdrop.Face(n)
% end




% PARTIALCORR CORRECTION FOR LICK
% If the covariance matrix of [X,Z] is S = [S11 S12; S12' S22], then the
% partial correlation matrix of X, controlling for Z, can be defined
% formally as a normalized version of the covariance matrix
% S = cov([X,lickSignal]);
% S11 = S(1:end-1,1:end-1);
% S12 = S(1:end-1, end);
% S22 = S(end,end);
% S_XZ = S11 - S12*inv(S22)*S12';
% lickCorrection = S12*inv(S22)*S12';









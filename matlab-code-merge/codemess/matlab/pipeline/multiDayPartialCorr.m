% md = loadMultiDayRoi_Reprocessed

%% GET PARTIALCORR
% xc = cat(1, md(1).procsum.xc)
for k=1:numel(md)
   R = md(k).roi;
   bhv = md(k).bhv;
   X = [R.RawTrace];
   nRoi = numel(R);
   nFrames = size(X,1);
   behaviorSignal =  znormalize(single([bhv.soundlogical.all,...
	  bhv.soundlogical.firstsecond,...
	  bhv.soundlogical.long,...
	  bhv.soundlogical.short]));
   %    lickSignal = single(bhv.licklogical.first.soundlick);
   lickSignal = znormalize(single(bhv.licklogical.lick));
   [rho,pval] = partialcorr(znormalize(X), behaviorSignal, lickSignal);
   
   pThresh = .01;
   signif = pval < pThresh;
   Rsig.sound = R(signif(:,1));
   Rsig.long = R(signif(:,3));
   Rsig.short = R(signif(:,4));
   Rsig.bothsound = R(signif(:,3) & signif(:,4));
   Rsig.longonly = R(signif(:,3) & ~signif(:,4));
   Rsig.shortonly = R(signif(:,4) & ~signif(:,3));
   Rsig.firstsecond = R(signif(:,2));
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
   h = show([R(~any(signif,2)) ; R(any(signif,2))]);
   drawnow
   
   
   pcor(k).rho = rho;
   pcor(k).pval = pval;
   pcor(k).signif = signif;
   pcor(k).sigroi = Rsig;
   try
	  pcor(k).frame = getframe(h.fig);
	  pcor(k).h = h;
	  close(h.fig)
   catch me
   end
   % EVALUATE TIME DEPENDENDENCE
   for kShuf = 1:5
	  % SHUFFLE ROI SIGNAL
	  pcorshuf(k,kShuf).xshuf.shift = fix( nFrames .* (rand(nRoi,1) - 1/2) );
	  xshuf = X;
	  for kx = 1:nRoi
		 xshuf(:,kx) = circshift(xshuf(:,kx), pcorshuf(k,kShuf).xshuf.shift(kx));
	  end
	  [rho,pval] = partialcorr(znormalize(xshuf), behaviorSignal, lickSignal);
	  pcorshuf(k,kShuf).xshuf.rho = rho;
	  pcorshuf(k,kShuf).xshuf.pval = pval;
	  % SHUFFLE BEHAVIOR SIGNAL
	  pcorshuf(k,kShuf).bhvshuf.shift = fix( nFrames * (rand - 1/2));
	  bhvshuf = circshift(behaviorSignal, pcorshuf(k,kShuf).bhvshuf.shift);
	  [rho,pval] = partialcorr(X, bhvshuf, lickSignal);
	  pcorshuf(k,kShuf).bhvshuf.rho = rho;
	  pcorshuf(k,kShuf).bhvshuf.pval = pval;
	  % SHUFFLE LICK SIGNAL
	  pcorshuf(k,kShuf).lickshuf.shift = fix( nFrames * (rand - 1/2));
	  lickshuf = circshift(lickSignal, pcorshuf(k,kShuf).lickshuf.shift);
	  [rho,pval] = partialcorr(X, behaviorSignal, lickshuf);
	  pcorshuf(k,kShuf).lickshuf.rho = rho;
	  pcorshuf(k,kShuf).lickshuf.pval = pval;
   end
   
   %    for kShuf = 1:5
   % 	  [~,pcorshuf(k,kShuf).idx] = sort(rand(numel(bhv.soundlogical.all),1));
   % 	  [rho,pval] = partialcorr(X, behaviorSignal(pcorshuf(k,kShuf).idx, :), lickSignal(pcorshuf(k,kShuf).idx, :));
   % 	  pcorshuf(k,kShuf).rho = rho;
   % 	  pcorshuf(k,kShuf).pval = pval;
   %    end
end
roiframe = cat(1,pcor.frame);
imaqmontage(cat(4,roiframe.cdata))
ax = gca;
ax.DataAspectRatio = [1 1 1];
ax.Position = [0 0 1 1];
title(['Top Correlators (p>.01) with LONG (Red),  SHORT (Green), and BOTH (Blue) Tones:',...
   'corrected for correlation with all licks using partialcorr function ']);

% figure;
%  histogram(pcorshuf(1,1).xshuf.rho(:,3)), hold on, histogram(pcorshuf(1,1).xshuf.rho(:,4))
% histogram(pcor(1).rho(:,3)), histogram(pcor(1).rho(:,4))
% figure
% scatterhist(pcorshuf(1,1).xshuf.rho(:,3), pcorshuf(1,1).xshuf.rho(:,4), '.');
% hold on
% scatterhist(pcor(1).rho(:,3), pcor(1).rho(:,4), '.');
figure,
scatter(pcor(1).pval(:,1), pcorshuf(1,1).xshuf.pval(:,1), 'Marker','.')
hold on
scatter(pcor(1).pval(:,1), pcorshuf(1,2).xshuf.pval(:,1), 'Marker','.')
scatter(pcor(1).pval(:,1), pcorshuf(1,3).xshuf.pval(:,1), 'Marker','.')
scatter(pcor(1).pval(:,1), pcorshuf(1,4).xshuf.pval(:,1), 'Marker','.')
scatter(pcor(1).pval(:,1), pcorshuf(1,5).xshuf.pval(:,1), 'Marker','.')
title('Partial Correlation Pvalue of Real-Data vs. Randomly Shifted CA-FLUORESCENCE')
xlabel('Unshifted X P-Value')
ylabel('Randomly-Shifted X P-Value')

figure,
scatter(pcor(1).pval(:,1), pcorshuf(1,1).bhvshuf.pval(:,1), 'Marker','.')
hold on
scatter(pcor(1).pval(:,1), pcorshuf(1,2).bhvshuf.pval(:,1), 'Marker','.')
scatter(pcor(1).pval(:,1), pcorshuf(1,3).bhvshuf.pval(:,1), 'Marker','.')
scatter(pcor(1).pval(:,1), pcorshuf(1,4).bhvshuf.pval(:,1), 'Marker','.')
scatter(pcor(1).pval(:,1), pcorshuf(1,5).bhvshuf.pval(:,1), 'Marker','.')
title('Partial Correlation Pvalue of Real-Data vs. Randomly Shifted SOUND-ONSET')
xlabel('Unshifted X P-Value')
ylabel('Randomly-Shifted Sound-Onset P-Value')

figure,
scatter(pcor(1).pval(:,1), pcorshuf(1,1).lickshuf.pval(:,1), 'Marker','.')
hold on
scatter(pcor(1).pval(:,1), pcorshuf(1,2).lickshuf.pval(:,1), 'Marker','.')
scatter(pcor(1).pval(:,1), pcorshuf(1,3).lickshuf.pval(:,1), 'Marker','.')
scatter(pcor(1).pval(:,1), pcorshuf(1,4).lickshuf.pval(:,1), 'Marker','.')
scatter(pcor(1).pval(:,1), pcorshuf(1,5).lickshuf.pval(:,1), 'Marker','.')
title('Partial Correlation Pvalue of Real-Data vs. Randomly Shifted LICK-TIMES')
xlabel('Unshifted X P-Value')
ylabel('Randomly-Shifted Lick P-Value')



%% SHOW PARTIALCORR
kDay=1;
t = md(kDay).bhv.t;
topcor.all = find(pcor(5).pval(:,1) < .001);
topcor.fs = find(pcor(5).pval(:,2) < .001);
topcor.long = find(pcor(5).pval(:,3) < .001);
topcor.short = find(pcor(5).pval(:,4) < .001);
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
close
% nRoi = min(numel(topcor.long), numel(topcor.short));
nRoi = numel(topcor.fs);
hIm = image(t,[0 nRoi], trialdata, 'AlphaData', .1);
hAx = gca;
hAx.Position = [0 0 1 1];
hold on
for kRoi = 1:nRoi;
   hLine(kRoi,1) = line(t, pnormalize(md(kDay).roi(topcor.fs(kRoi)).Trace)+kRoi-1, 'Color', 'k');
   %    hLine(kRoi,2) = line(t, pnormalize(md(kDay).roi(topcor.short(kRoi)).Trace)+kRoi-1, 'Color', 'g');
end
axis xy
ylim([0 nRoi+1]);

%%
kRoi = 1;
x = md(kDay).roi(topcor.long(kRoi)).Trace;
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









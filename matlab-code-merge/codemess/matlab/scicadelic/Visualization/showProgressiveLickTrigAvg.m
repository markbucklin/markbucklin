clf
lta.daynum = 4;
X = [md(lta.daynum).roi.Trace];
lta.winsize = 20*20;
lta.prelick = 20*3;
lta.tau = (-lta.prelick:lta.winsize-(lta.prelick+1))/20;
lta.roinum = 311;
f = zeroShiftedWinMat(X(:,lta.roinum), lta.winsize);
f = bsxfun(@minus, f, f(lta.tau == 0,:));
lta.iqr = iqr(f(:));
lta.lim = mean(f(:)) + [-lta.iqr lta.iqr];
lta.hline = [];
vidobj = VideoWriter(sprintf('Progressive Lick Triggered Average - Day%d - Roi%d',lta.daynum, lta.roinum),'MPEG-4');
open(vidobj);
for k=1:195
   if ~isempty(lta.hline)
	  ax = gca;
	  ax.NextPlot = 'add';
	  for kc = 1:4
		 lta.hline(kc).Color = [ lta.hline(kc).Color, .1];
		 lta.hline(kc).LineWidth = .5;
	  end
	  ax.ColorOrderIndex = 1;
   end
   lta.framek = md(lta.daynum).bhv.frameidx.firstlick(k);
   lta.firstlickframes = md(lta.daynum).bhv.frameidx.firstlick(1:k);
   lta.shortlickframes = md(lta.daynum).bhv.frameidx.shortlick(ceil(1:(k/2)));
   lta.longlickframes = md(lta.daynum).bhv.frameidx.longlick(ceil(1:(k/2)));
   lta.firstlickframes = lta.firstlickframes(~isnan(lta.firstlickframes));
   lta.longlickframes = lta.longlickframes(~isnan(lta.longlickframes));
   lta.shortlickframes = lta.shortlickframes(~isnan(lta.shortlickframes));
   lta.hline = plot(lta.tau, cat(2,...
	  nanmean( f(:,lta.firstlickframes ), 2),...
	  nanmean(f(:, lta.shortlickframes), 2),...
	  nanmean(f(:, lta.longlickframes), 2),...
	  nanmean( f(:,md(lta.daynum).bhv.frameidx.alllicks(md(lta.daynum).bhv.frameidx.alllicks < lta.framek) ), 2) ));
   set(lta.hline, 'LineWidth', 2);
   axis tight
   ylim(lta.lim)
   grid on
   legend('First Lick (all tones)','first Long lick','first Short lick', 'all licks')
   title(sprintf('Fluorescence average aligned to licks in trials 1 to %d',k))
   drawnow
   lta.frame(k) = getframe(gcf);
   vidobj.writeVideo(lta.frame(k));
end
close(vidobj)
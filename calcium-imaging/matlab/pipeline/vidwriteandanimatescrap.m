
%%
info.Dt(1:5) = info.Dt(6:10);


%%
df = 400;
info.Straightness = ...
	info.ForwardVelocity ./ ...
	(abs(info.RotationalVelocity)+1);%mean(info.ForwardVelocity));
movingSignal = filtfilt(ones(20,1), 1,info.Straightness);
% [~,idx] = sort(movingSignal);
% movingSignalFrames = fliplr(idx(:)');
goFrames = find(info.Straightness > 2*mean(info.Straightness));
[~,ind] = unique( 2*df * round(goFrames/(2*df)));
goFrames = goFrames(ind);
goFrames = goFrames(goFrames>df);

slowFrames = find(info.Straightness < .5*mean(info.Straightness));
[~,ind] = unique( 2*df * round(slowFrames/(2*df)));
slowFrames = slowFrames(ind);
slowFrames = slowFrames(slowFrames>df);

dnr = diff([0; info.NumRewardsGiven]);
dnr(dnr>1) = 0;
smallReward = dnr>0 & dnr<1;
largeReward = dnr>.5;
largeRewardFrames = find(largeReward);
[~,ind] = unique( df * round(largeRewardFrames/df));
largeRewardFrames = largeRewardFrames(ind); %gets rid of quick repeats...
smallRewardFrames = find(smallReward);
largeRewardInterval = diff([0;largeRewardFrames]);
smallRewardInterval = diff([0;smallRewardFrames]);

N = min([numel(goFrames) numel(slowFrames) numel(largeRewardFrames)]);

channelFrames.blue.trigger = largeRewardFrames(1:N);
channelFrames.green.trigger = goFrames(1:N);
channelFrames.red.trigger = slowFrames(1:N);


%%
kCondition = {'slow','go','largeReward'};
kColor = {'red','green','blue'};
for k=1:3
	triggerFrames = channelFrames.(kColor{k}).trigger;
	channelFrames.(kColor{k}).condition = kCondition{k};
	for trialNum = 1:N
		fPre = triggerFrames(trialNum) - df + 1;
		fPost = triggerFrames(trialNum) + df;
		channelFrames.(kColor{k}).fPre(trialNum) = fPre;
		channelFrames.(kColor{k}).fPost(trialNum) = fPost;
		kVid(:,:,1,:,trialNum) = cat(4, vid(fPre:fPost).cdata );
	end
	% 	rgbVid(:,:,k,:) = uint8(mean(kVid, 5));
	rgbVid(:,:,k,:) = max(kVid, [], 5);
end


%%
filename = uiputfile('*.mp4');
profile = 'MPEG-4';
fps = round(1/mean(info.Dt));
writerObj = VideoWriter(filename,profile);
writerObj.FrameRate = fps;
writerObj.Quality = 90;
open(writerObj)
writeVideo(writerObj,rgbVid)
close(writerObj)


%%
colordef none
hWorld = handle(w.draw3D);
hFig = handle(gcf);
set(hFig,'Position', [150 150 2200 1100]);
set(hFig,'Units','normalized');
hAx(1) = handle(gca);
hAx(1).GridLineStyle = 'none';
hAx(1).DrawMode = 'fast';
hAx(1).PlotBoxAspectRatio = [200 200 14];
hAx(1).Position = [0 0 .5 1];
hAx(1).XLim = [-110 110];
hAx(1).YLim = [-110 110];
hAx(1).ZLim = [-1 25];
hWorld.FaceAlpha = .8;

for k=1:3
	trialNum = 1;
	f1 = channelFrames.(kColor{k}).fPre(trialNum);
	f2 = f1 + 10;
	hLine(k) = handle(line(info.Xpos(f1:f2), info.Ypos(f1:f2), 'Parent', hAx(1)));
	hLine(k).LineWidth = 1.5;
	p.xverts = [2 0 -2 0];
	p.yverts = [0 -2 0 2];
	p.zverts = [1 1 1 1];
	hPatch(k) = handle(patch(info.Xpos(f2)+p.xverts, info.Ypos(f2)+p.yverts, p.zverts,...
		kColor{k},...
		'Parent', hAx(1)));
	hPatch(k).FaceAlpha = 1;
end
hAx(2) = handle(axes('Parent',hFig, 'Position',[.5 0 .5 .5]));
hIm = handle(image(rgbVid(:,:,:,1), 'Parent',hAx(2)));

numRewards = 0;
for nTrial = 1:N	
	for nFrame = 
	for k=1:3
		hLine(k).XData=info.Xpos(k:k+500); hLine(k).YData=info.Ypos(k:k+500);
		hPatch(k).XData = info.Xpos(k+500)+p.xverts;
		hPatch(k).YData = info.Ypos(k+500)+p.yverts;
		if info.NumRewardsGiven(k+500) > numRewards+.5
			hPatch(k).FaceAlpha = 1;
			numRewards = info.NumRewardsGiven(k+500);
		else
			hPatch(k).faceAlpha = hPatch(k).faceAlpha * .99;
		end
		drawnow
	end
end





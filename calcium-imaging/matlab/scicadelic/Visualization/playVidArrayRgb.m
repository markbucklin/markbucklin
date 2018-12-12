function playVidArrayRgb(vid)

nFrames = size(vid,4);
hFig = handle(figure(1));
hFig.Units = 'normalized';
hFig.Position = [.2 .1 .6 .8];
axes('parent',hFig,'position', [0 0 1 1]);
hAx = handle(gca);
hIm = handle(imshow(vid(:,:,:,1),...
	'Parent',hAx));
hText = handle(text(100,20,sprintf('Frame: 0/%i',nFrames)));
whitebg('k')

% MOVIE
for k=1:nFrames
	hIm.CData = vid(:,:,:,k);
	hText.String = sprintf('Frame %i/%i',k,nFrames);
	if nFrames < 100
		pause(.1)
	end
	drawnow
end
close(hFig)

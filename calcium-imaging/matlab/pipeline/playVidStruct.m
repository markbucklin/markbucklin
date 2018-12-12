function playVidStruct(vid)

% DISPLAY/COMPARE
N = numel(vid);
vs = getVidSample(vid,500);
inputRange = [min(min( cat(1,vs.cdata), [],1), [],2) , max(max( cat(1,vs.cdata), [],1), [],2)];
% fileString = vid(1).info.Filename;
[~, fn] = fileparts(vid(1).info.Filename);
fileString = fn;
N = min(numel(vid), N);
hFig = handle(figure);
hFig.Units = 'normalized';
axes('parent',hFig,'position', [0 0 1 1]);
hAx = handle(gca);
hIm = handle(imshow(vid(1).cdata,...
	'DisplayRange', inputRange,...
	'Parent',hAx));
hFileText = handle(text(10,20, fileString));
hText = handle(text(10,50,sprintf('Frame: 0/%i',N)));
whitebg('k')
hFig.Colormap = gray(256);

% MOVIE
for k=1:N
   try
	hIm.CData = vid(k).cdata;
	hText.String = sprintf('Frame %i/%i',k,N);
	drawnow
   catch me
      if isvalid(hFileText)
         hFileText.String = me.message;
      end
      return
   end
end
close(hFig)


% t = timer('ExecutionMode','fixedRate',...
% 	'BusyMode','drop',...
% 	'TasksToExecute',N,...
% 	'TimerFcn',@nextFrame,...
% 	'Period',1/fps);
% set(gcf,'CloseRequestFcn','stop(t),delete(t)')
% hTitle = title(sprintf('frame %g of %g',1,N));
% start(t)


% 	function nextFrame(obj,evnt)
% 		frameNum = obj.TasksExecuted + 1;
% 		vp.step(imadjust(vid(frameNum).cdata,[imLow imHigh]));
% 	end
% end
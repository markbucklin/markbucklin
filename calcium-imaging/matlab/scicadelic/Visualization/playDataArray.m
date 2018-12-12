function playDataArray(data, fps)

if nargin < 2
   fps = 20;
end

% DISPLAY/COMPARE
if ndims(data) == 4
  playVidArrayRgb(data)
  return
end
sz = size(data);
h.nFrames = size(data,3);
inputRange = [getNearMin(data) , getNearMax(data)];

% if nargin < 2
% 	P = [ 20 99.995];
% else
% 	P = varargin{1};
% end
% if numel(P) ~=2
% 	P = [ 20 99.9];
% 	warning('vidStruct2uint16:InvalidSaturationLimits',...
% 		'Saturation limits set to 20th (low) and 99.9th (high) percentiles')
% end
% sampleFrames = unique(round(linspace(1, nFrames, 25)));
% sampleVid = vid(:,:, sampleFrames);
% Y = prctile(sampleVid(:), P);
% imin = Y(1);
% imax = Y(2);

h.Fig = handle(figure(1));
h.Fig.Units = 'normalized';
setpixelposition(h.Fig,[10 100 sz(2) sz(1)]);
axes('parent',h.Fig,'position', [0 0 1 1]);
h.Ax = handle(gca);
h.Im = handle(imshow(data(:,:,1),...
	'DisplayRange', inputRange,...
	'Parent',h.Ax));
h.Text = handle(text(100,20,sprintf('Frame: 0/%i',h.nFrames)));
whitebg('k')
h.data = data;

t = timer(...
			 'ExecutionMode','fixedRate',...
			 'BusyMode','queue',...
			 'Period',1/fps,...
			 'UserData',h,...
			 'TimerFcn', @dataPlayerUpdate);
		  assignin('base','vidTimer',t);
		  start(t)
end
function dataPlayerUpdate(src,evnt)		
h = src.UserData;
if ~isvalid(h.Im)
   fprintf('Video CLOSED\n')
   stop(src)
   return
end

k = get(src,'TasksExecuted')+1;
if k > h.nFrames		% Finished
   stop(src);
   delete(src);
else
   h.Im.CData = h.data(:,:,k);
   h.Text.String = sprintf('Frame %i/%i',k,h.nFrames);
   drawnow   
end

end






% % MOVIE
% for k=1:nFrames
% 	hIm.CData = data(:,:,k);
% 	hText.String = sprintf('Frame %i/%i',k,nFrames);
% 	if nFrames < 100
% 		pause(.1)
% 	end
% 	drawnow
% end
% close(hFig)


% t = timer('ExecutionMode','fixedRate',...
% 	'BusyMode','drop',...
% 	'TasksToExecute',nFrames,...
% 	'TimerFcn',@nextFrame,...
% 	'Period',1/fps);
% set(gcf,'CloseRequestFcn','stop(t),delete(t)')
% hTitle = title(sprintf('frame %g of %g',1,nFrames));
% start(t)


% 	function nextFrame(obj,evnt)
% 		frameNum = obj.TasksExecuted + 1;
% 		vp.step(imadjust(vid(frameNum).cdata,[imLow imHigh]));
% 	end
% end
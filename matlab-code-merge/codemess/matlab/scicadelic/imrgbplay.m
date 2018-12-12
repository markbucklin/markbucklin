function varargout = imrgbplay(F, framePeriod, immediateStart, catWithPrevious)
% IMSCPLAY
%
% Usage:
%		>> imrgbplay(F)
%		>> imrgbplay(F, .05)
%		>> imrgbplay(F, .05, true)
%		>> h = imrgbplay(F, 1/fps, true)
%
% Mark Bucklin
% 9/1/2015




% ============================================================
% INPUT
% ============================================================
if nargin < 4
	catWithPrevious = [];
	if nargin < 3
		immediateStart = [];
		if nargin < 2
			framePeriod = [];
		end
	end
end
if isempty(framePeriod)
	framePeriod = .04;
end
if isempty(immediateStart)
	immediateStart = true;
end
if isempty(catWithPrevious)
	catWithPrevious = false;
end
if isa(F, 'gpuArray')
	F = gather(F);
end


% ============================================================
% DETERMINE COLOR/TIME DIMENSIONS
% ============================================================
[numRows, numCols, dim3, dim4] = size(F);
if dim3 < 4
	numChannels = dim3;
	numFrames = dim4;
	colorDim = 3;
	timeDim = 4;
	
elseif dim4 < 4
	numChannels = dim4;
	numFrames = dim3;
	colorDim = 4;
	timeDim = 3;
	
else
	error('IMRGBPLAY currently only handles 3 color channels')
	
end
framePlayIncrement = 1;
beep off

% ============================================================
% RESCALE
% ============================================================
% inputClim = approximateClim(F);
if ~isa(F, 'uint8')
	F = single(F);
	lowLim = approximateFrameMinimum(F, .20);
	highLim = approximateFrameMaximum(F, .001);
	% lowLim = gather(temporalArFilterRunGpuKernel(gpuArray(lowLim), .97));
	% highLim = gather(temporalArFilterRunGpuKernel(gpuArray(highLim), .97));
	limRange = highLim - lowLim;
	F = bsxfun(@times, bsxfun(@minus, F, lowLim), 1./limRange);
	if colorDim ~= 3
		F = permute(F, [1 2 colorDim timeDim]);
	end
	F = uint8(255.*F); %TODO: store as int16 and add rgbOffset and rgbScale
else
	lowLim = 0;
	highLim = 255;
end
% if numChannels ~= 3  % TODO
% 	F = repmat(F, 1, 1, 3-numChannels, 1);
% end



% ============================================================
% MANAGE GRAPHICS HANDLES
% ============================================================
% todo: fix multi-channel
hGRoot = handle(groot);
figName = 'imrgbplay-fig';
hGRoot.ShowHiddenHandles = 'on';
curFig = findobj(hGRoot.Children, 'Name', figName);
hGRoot.ShowHiddenHandles = 'off';
if ~isempty(curFig)
	h.fig = handle(curFig);
else
	h.fig = handle(figure);
end
curAx = findobj(h.fig.Children, 'type','axes');
if ~isempty(curAx)
	h.ax = curAx;
	h.im = findobj(h.ax.Children, 'type', 'image');
else
	try
		h = addRgbImage(F);
	catch me
		msg = getReport(me);
		error(msg)
	end
	% 	h.ax = h.im.Parent;
	h.fig = h.ax.Parent;
	catWithPrevious = false;
end


% SCROLLPANEL & ZOOMBOX (IPT API, EXPERIMENTAL)
hScroll = findobj(h.fig.Children, 'tag','imscrollpanel');
if ~isempty(hScroll) && isvalid(hScroll)
	h.scrollpan = hScroll;
else
	h.scrollpan = imscrollpanel(h.fig,h.im);
end
% h.scrollpan.Tag = 'scrollpan';
hBox = findobj(h.fig.Children, 'tag','immagbox');
if ~isempty(hBox) && isvalid(hBox)
	h.box = hBox;
else
	h.box = immagbox(h.fig,h.im);
end
h.pixinfopanel = impixelinfo(h.fig, h.im);
h.zoomboxapi = iptgetapi(h.box);
h.scrollpanapi = iptgetapi(h.scrollpan);
fitMag = h.scrollpanapi.findFitMag();
h.scrollpanapi.setMagnification(fitMag);
delete(findobj(h.fig.Children, 'tag', 'Copy pixel info menu item'))

% AXES
h.ax = findobj(h.scrollpan.Children,'type','axes');






% ============================================================
% FIGURE/AXES/IMAGE SETTINGS
% ============================================================
% FIGURE SETTINGS
h.fig.Name = figName;
h.fig.IntegerHandle = 'off';
h.fig.HandleVisibility = 'off';
h.fig.CloseRequestFcn = @closeFigure;
whitebg(h.fig, 'k')
h.fig.Interruptible = 'off';
h.fig.BusyAction = 'cancel';

% AXES SETTINGS
h.ax.Box = 'off';
h.ax.XColor = [0 0 0];
h.ax.YColor = [0 0 0];

% IMAGE SETTINGS
h.im.ButtonDownFcn = @winClickControlFcn;

% ENABLE FIGURE RESPONSE TO KEYBOARD/MOUSE SHORTCUTS WHILE ZOOMED
hManager = uigetmodemanager(h.fig);
try
	set(hManager.WindowListenerHandles, 'Enable', 'off');  % HG1
catch
	[hManager.WindowListenerHandles.Enabled] = deal(false);  % HG2
end


% % SCROLLPANEL & ZOOMBOX (IPT API, EXPERIMENTAL)
% h.scrollpan = imscrollpanel(h.fig,h.im);
% h.box = immagbox(h.fig,h.im);
% h.zoomboxapi = iptgetapi(h.box);
% h.scrollpanapi = iptgetapi(h.scrollpan);
% fitMag = h.scrollpanapi.findFitMag();
% h.scrollpanapi.setMagnification(fitMag);
% h.im.ButtonDownFcn = @winClickControlFcn;



% ============================================================
% ADD TEXT
% ============================================================
% ADD DESCRIPTIVE TEXT IN UPPER LEFT CORNER
h.text = findobj(h.ax, 'Type','text');
if isempty(h.text)
	txtString = sprintf('[%d]',1);
	h.text = text(20,50,txtString,...
		'Parent', h.ax,...
		'FontSize', 20,...
		'Color', [.1 .4 .1 .7],...
		'BackgroundColor',[.3 .3 .3 .5],...
		'EdgeColor','none',...
		'FontWeight', 'bold');
end



% ============================================================
% GET CURRENT WINDOW TIMER OR CREATE NEW
% ============================================================
if isappdata(h.fig, 't')
	frameTimer = getappdata(h.fig, 't');
	if ~isvalid(frameTimer)
		frameTimer = setupFrameTimer();
	else
		frameTimer = setupFrameTimer(frameTimer);
	end
else
	frameTimer = setupFrameTimer();
end
previousRunning = strcmpi(frameTimer.Running, 'on');
if ~previousRunning || ~catWithPrevious
	setappdata(h.fig, 'k',1);
end



% ============================================================
% CONCATENATE WITH PREVIOUS FIGURE DATA & ADD AS FIGURE RESOURCE
% ============================================================
if catWithPrevious && isappdata(h.fig, 's')
	% 		stop(frameTimer) % NEW
	prevsource = getappdata(h.fig,'s');
	try
		figsource.f = cat(ndims(F), prevsource.f, F);
		figsource.n = prevsource.n + numFrames;
		figsource.imhandle = prevsource.imhandle;
	catch me
		showError(me)
		catWithPrevious = false;
	end
else
	catWithPrevious = false;
end
if ~catWithPrevious
	figsource.f = F;
	figsource.n = numFrames;
	figsource.imhandle = h.im;
	% 	setappdata(h.fig, 't',frameTimer);
end
setappdata(h.fig, 't',frameTimer);%NEW
setappdata(h.fig, 's',figsource);



% ============================================================
% USER RESPONSE CALLBACK FUNCTIONS
% ============================================================
h.fig.KeyPressFcn = @keyPressControlFcn;
h.fig.WindowScrollWheelFcn = @scrollWheelControlFcn;
h.fig.DeleteFcn = @deleteTimerFcn;
h.fig.CloseRequestFcn = @deleteTimerFcn;
previousRunning = strcmpi(frameTimer.Running, 'on');
if immediateStart && ~previousRunning
	start(frameTimer)
end



% ============================================================
% OUTPUT
% ============================================================
if nargout
	varargout{1} = h;
end




% ##################################################
% SUBFUNCTIONS #####################################
% ##################################################

	function t = setupFrameTimer(t)
		if nargin < 1
			t = timer;
		end
		set(t, ...
			'ExecutionMode', 'fixedDelay',...
			'Period', framePeriod, ...
			'StartDelay', framePeriod,...
			'TimerFcn', @playNextFrame, ...
			'BusyMode', 'drop',...
			'ErrorFcn', @(src,envt) delete(src));%,...
	end
	function keyPressControlFcn(src, evnt)
		
		modKeySet = evnt.Modifier;
		
		if isempty(modKeySet)
			% KEYBOARD COMMANDS (UNMODIFIED)
			switch evnt.Key
				case 'leftarrow'
					playPreviousFrame()
				case 'rightarrow'
					playNextFrame(src)
				case 'uparrow'
					% 					changeBrightness(.01);
				case 'downarrow'
					% 					changeBrightness(-.01);
				case 'space'
					startStopPlayToEnd()
				case 'escape'
					closeFigure(src,evnt)
			end
		else
			if numel(modKeySet) == 1
				modKey = modKeySet{1};
				% KEYS USED WITH SINGLEMODIFIER (CTRL, ALT, SHIFT,...)
				switch modKey
					case 'control'
						switch evnt.Key
							case 'leftarrow'
								setFrame(1)
							case 'rightarrow'
								setFrame(numFrames)
							case 'uparrow'
								% 								changeContrast(.01);
							case 'downarrow'
								% 								changeContrast(-.01);
							case 'space'
								set(h.ax,'CLim', approximateClim(h.im.CData));
						end
						
					case 'alt'
						switch evnt.Key
							case 'rightarrow'
								setPlaySpeed(1.1)
							case 'leftarrow'
								setPlaySpeed(.9)
						end
						
					case 'shift'
						switch evnt.Key
							case 'leftarrow'
								setFrameRelative(-max(8,ceil(numFrames/256)))
							case 'rightarrow'
								setFrameRelative(max(8,ceil(numFrames/256)))
						end
					otherwise
						fprintf('Modifier Key Pressed: %s\n',modKey)
				end
			else
				
			end
		end
		
		
	end
	function scrollWheelControlFcn(src,evnt)
		scrollCount = evnt.VerticalScrollCount;
		scrollAmount = evnt.VerticalScrollAmount;
		currentChar = src.CurrentCharacter;
		if scrollCount ~= 0
			% 			currentLim = double(get(h.ax,'CLim'));
			% 			dLim = .005*scrollCount*scrollAmount*(currentLim(2)-currentLim(1));
			switch currentChar
				case {'b', 'f'} % BRIGHTNESS
					% 					set(gca,'CLim', cast(currentLim + dLim,'like',currentLim));
					% 					changeBrightness( .005*scrollCount*scrollAmount);
				case {'c', 'd'} % CONTRAST
					% 					set(gca,'CLim', cast( currentLim + [-dLim dLim],'like',currentLim));
					% 					changeContrast( .005*scrollCount*scrollAmount);
				otherwise % FRAME NUMBER
					switch scrollCount
						case -1 % SCROLL-UP
							playPreviousFrame()
							
						case 1 % SCROLL-DOWN
							playNextFrame(src)
							
						otherwise % MULTISCROLL
							k = getappdata(h.fig,'k');
							setFrame(k+scrollCount)
					end
			end
		end
	end
	function winClickControlFcn(~,evnt)
		persistent lastClickTic
		if ~isempty(lastClickTic)
			doubleClickDelay = toc(lastClickTic);
			fitMag = h.scrollpanapi.findFitMag();
			curMag = h.scrollpanapi.getMagnification();
			curPt = evnt.IntersectionPoint(1:2);			
			if doubleClickDelay < .250
				switch evnt.Button
					case 1
						% 						h.scrollpanapi.setMagnificationAndCenter(1.5*curMag, curPt(1), curPt(1))
						if ~isfield(h, 'ovpanel') || isempty(h.ovpanel) || isstruct(h.ovpanel) || ~isvalid(h.ovpanel)
							h.ovpanel = imoverviewpanel(h.fig,h.im);
						end
						h.ovpanel.Units = 'Normalized';
						h.ovpanel.Position = [0 0 .25 .25];
						h.scrollpanapi.setMagnificationAndCenter(max(curMag,fitMag)*1.5, curPt(1), curPt(2))
						h.ovpanel.Visible = 'on';
						h.ovpanel.ButtonDownFcn = @winClickControlFcn;
					case 2
						
					case 3
						try
							h.scrollpanapi.setMagnification(fitMag)
							h.ovpanel.Visible = 'off';							
						catch me
						end						
				end
			end
		end
		lastClickTic = tic;
	end
	function playNextFrame(src,~)
		if nargin<1
			src = [];
		end
		if ~isempty(src) && isa(src, 'timer') %isRunning()
			fpsActual = 1/frameTimer.InstantPeriod;
			fpsRequested = 1/frameTimer.Period;
			fpsLagRatio = (fpsRequested - fpsActual)/fpsRequested;
			if (fpsLagRatio < .05)
				drawnow
			end
		end
		s = getappdata(h.fig,'s');
		k = getappdata(h.fig,'k');
		k = max(min(s.n, k + framePlayIncrement),1);
		s.imhandle.CData = s.f(:,:,:,k); %TODO: select multichannels
		if k >= s.n
			if isRunning
				stop(frameTimer)
			end
		end
		setappdata(h.fig, 'k', k);
		if ~isempty(h.text)
			h.text.String = sprintf('[%d]',k);
		end
		
		% CHECK PLAY SPEED (APPLY SKIP IF TOO SLOW)
		% 		if frameTimer.TasksExecuted > 100 ...
		% 				&& ~isnan(frameTimer.AveragePeriod) ...
		% 				&&  isRunning()
		%
		% 			fpsActual = 1/frameTimer.AveragePeriod;
		% 			fpsLagRatio = (fpsRequested - fpsActual)/fpsRequested;
		% 			if (fpsLagRatio > .5)
		% 				framePlayIncrement = framePlayIncrement + 1;
		% 				setPlaySpeed(1)
		% 				disp(framePlayIncrement)
		% 			end
		% 		end
		
	end
	function playPreviousFrame(~,~)
		
		s = getappdata(h.fig,'s');
		k = getappdata(h.fig,'k');
		k = min(max(1, k - 1), s.n);
		s.imhandle.CData = s.f(:,:,:,k);
		if ~isempty(h.text)
			h.text.String = sprintf('[%d]',k);
		end
		if k <= 1
			% 			beep % TODO: text of frame position, or slider
			% 			pause(.25)
			% 			k = s.n;
		end
		setappdata(h.fig, 'k', k);
		
	end
	function changeBrightness(dB)
		s = getappdata(h.fig,'s');
		currentLim = double(get(s.imhandle.Parent,'CLim'));
		limRange = (currentLim(2)-currentLim(1));
		if currentLim(1) ~= 0
			newLim = cast( currentLim - limRange*dB, 'like', currentLim);
		else
			newLim = cast( currentLim .* (1 - dB), 'like', currentLim);
		end
		if any(isinf(currentLim)) || any(isinf(newLim))
			s = getappdata(h.fig,'s');
			lowLim = min(s.imhandle.CData(:));
			highLim = max(s.imhandle.CData(:));
			newLim = [lowLim highLim];
		end
		set(h.ax,'CLim', newLim);
	end
	function changeContrast(dC)
		s = getappdata(h.fig,'s');
		currentLim = double(get(s.imhandle.Parent,'CLim'));
		limRange = (currentLim(2)-currentLim(1));
		newLim = cast( currentLim + limRange.*[dC -dC], 'like', currentLim);
		if any(isinf(currentLim)) || any(isinf(newLim))
			s = getappdata(h.fig,'s');
			lowLim = min(s.imhandle.CData(:));
			highLim = max(s.imhandle.CData(:));
			newLim = [lowLim highLim];
		end
		set(h.ax,'CLim', newLim);
	end
	function startStopPlayToEnd(varargin)
		% 		isRunning = strcmpi(frameTimer.Running, 'on'); % NEW
		if isRunning
			stop(frameTimer);
		else
			k = getappdata(h.fig,'k');
			s = getappdata(h.fig,'s');
			k = max(min(k, s.n),1);
			if k == s.n
				k = 1;
			end
			setappdata(h.fig,'k',k)
			start(frameTimer);
		end
	end
	function setFrame(k)
		% 		isRunning = strcmpi(frameTimer.Running, 'on');
		s = getappdata(h.fig,'s');
		k = max(min(s.n, k),1);
		s.imhandle.CData = s.f(:,:,:,k);
		setappdata(h.fig, 'k', k);
		if ~isempty(h.text)
			h.text.String = sprintf('[%d]',k);
		end
	end
	function setFrameRelative(dk)
		% 		isRunning = strcmpi(frameTimer.Running, 'on');
		drawnow
		s = getappdata(h.fig,'s');
		k = getappdata(h.fig,'k');
		k = max(min(s.n, k+dk),1);
		% 		isRunning = strcmpi(frameTimer.Running, 'on'); % NEW
		s.imhandle.CData = s.f(:,:,:,k);
		setappdata(h.fig, 'k', k);
		s.imhandle.CData = s.f(:,:,:,k);
		if k >= s.n
			if isRunning
				stop(frameTimer)
			end
		end
		setappdata(h.fig, 'k', k);
		if ~isempty(h.text)
			h.text.String = sprintf('[%d]',k);
		end
	end
	function setPlaySpeed(speedMult)
		wasRunning = isRunning();
		if wasRunning
			stop(frameTimer)
		end
		
		% REMOVE FRAME-SKIPPING IF PLAY SPEED IS DECREASED
		if (speedMult < 1) && (framePlayIncrement > 1)
			framePlayIncrement = framePlayIncrement - 1;
		end
		
		fpsCurrent = 1/frameTimer.Period;%framePlayIncrement/frameTimer.Period;
		fpsNew = fpsCurrent * speedMult;
		warning('off','MATLAB:TIMER:STARTDELAYPRECISION')
		warning('off','MATLAB:TIMER:RATEPRECISION')
		frameTimer.Period = framePlayIncrement/fpsNew;
		frameTimer.StartDelay = framePlayIncrement/fpsNew;
		
		% RESTART TIMER
		if wasRunning
			start(frameTimer)
		end
	end
	function closeFigure(src,~)
		try
			if isRunning
				stop(frameTimer)
			end
			if ~isempty(frameTimer) && isvalid(frameTimer)
				delete(frameTimer)
			end
			delete(src)
		catch
			delete(src)
		end
	end
	function timerStatus = isRunning()
		if ~isempty(frameTimer) && isvalid(frameTimer)
			timerStatus = strcmpi(frameTimer.Running, 'on');
		else
			timerStatus = false;
		end
	end
	function deleteTimerFcn(varargin)
		if ~isempty(frameTimer) && isvalid(frameTimer)
			isRunning = strcmpi(frameTimer.Running, 'on');
			if isRunning
				stop(frameTimer)
			end
			delete(frameTimer);
		end
		delete(h.fig)
	end
	function h = addRgbImage(im, h)
		
		% PROCESS INPUT
		if nargin < 2
			h = [];
		end
		im = squeeze(im);
		[nRows, nCols, nChannels, nFrames] = size(im);
		relativeFrameSize = [[nCols nRows]./max(nRows,nCols) , 1];
		
		% 		maxIm = [];
		% 		minIm = [];
		if nFrames > 1
			% 			maxIm = max(im,[],4);
			% 			minIm = min(im,[],4);
			frameNum = 1;
			im = squeeze(im(:,:,:,frameNum));
		end
		warning('off','MATLAB:Figure:SetPosition')
		
		
		% INITIALIZE GRAPHICS OBJECTS (WINDOW, IMAGE, AXES)
		if isempty(h)
			h.im = handle(image(im));
			h.ax = handle(h.im.Parent);
			h.fig = handle(h.ax.Parent);
			
			h.fig.Units = 'normalized';
			h.fig.Renderer = 'opengl';
			h.ax.Position = [0.005 .005 .99 .99];
			h.ax.PlotBoxAspectRatioMode = 'manual'; % DataAspectRatio
			h.ax.PlotBoxAspectRatio = oncpu(relativeFrameSize);
			h.ax.XTick = [];
			h.ax.YTick = [];
			h.ax.SortMethod = 'childorder';
		else
			h.im = handle(image(h.ax, im));
		end
		
		% POSITION (experimental)
		if nargin < 2
			h.fig.OuterPosition = [.5 .050 .5 .95];
			h.fig.BackingStore = 'on';
			h.fig.DoubleBuffer = 'on';
			h.fig.GraphicsSmoothing = 'on';
		end
		% h.fig.MenuBar = 'none';
		% Interruptible
		% Alphamap
		% UpdateToken
		% LoadData
		% NextPlot
		% WaitStatusMode
		% h.fig.ApplicationData
		% ControllerMode
		% Controller
		% ControllerInfo
		% Clipping
		% Behavior
		% NextPlotMode
		% tic, getframe(h); toc - 0.13 sec
		% tic, addframe(h); toc - 0.15 sec
		% tic, hardcopy(h,'-Dpainters','r0'); toc - 0.07 sec
		
		assignin('base', 'hImrgb', h);
		
		if nargout
			% 			varargout{1} = h.im;
			varargout{1} = h;
		end
	end
	function f = oncpu(f)
		if isa(f,'gpuArray')
			if isfloat(f)
				f = single(gather(f));
			else
				f = gather(f);
			end
		else
			f = single(f);
		end
		
	end


end














function varargout = imscplay(F, framePeriod, immediateStart, catWithPrevious)
warning('imscplay.m being called from scrap directory: Z:\Files\MATLAB\toolbox\ignition\scrap')
% IMSCPLAY
%
% Usage:
%		>> imscplay(F)
%		>> imscplay(F, .05)
%		>> imscplay(F, .05, true)
%		>> h = imscplay(F, 1/fps, true)
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
N = oncpu(size(F,ndims(F)));

framePlayIncrement = 1;
fpsActual = [];
beep off


% ============================================================
% MANAGE GRAPHICS HANDLES
% ============================================================
% todo: fix multi-channel
hGRoot = handle(groot);
figName = 'imscplay-fig';
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
		h = addScaledImage(F);
	catch me
		msg = getReport(me);
		error(msg)
	end
	% 	h.ax = h.im.Parent;
	h.fig = h.ax.Parent;
	catWithPrevious = false;
end

% ZOOM CONTROL
% h.zoom = zoom(h.fig);

% SCROLLPANEL & ZOOMBOX (IPT API, EXPERIMENTAL)
hScroll = findobj(h.fig.Children, 'tag','imscrollpanel');
if ~isempty(hScroll) && isvalid(hScroll)
	h.scrollpan = hScroll;
else
	h.scrollpan = imscrollpanel(h.fig,h.im);
end
hBox = findobj(h.fig.Children, 'tag','immagbox');
if ~isempty(hBox) && isvalid(hBox)
	h.box = hBox;
else
	h.box = immagbox(h.fig,h.im);
end
h.zoomboxapi = iptgetapi(h.box);
h.scrollpanapi = iptgetapi(h.scrollpan);
fitMag = h.scrollpanapi.findFitMag();
h.scrollpanapi.setMagnification(fitMag);
h.pixinfopanel = impixelinfo(h.fig, h.im);
delete(findobj(h.fig.Children, 'tag', 'Copy pixel info menu item'))

h.ax = findobj(h.scrollpan.Children,'type','axes');
h.im.ButtonDownFcn = @winClickControlFcn;



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


% ENABLE FIGURE RESPONSE TO KEYBOARD/MOUSE SHORTCUTS WHILE ZOOMED
hManager = uigetmodemanager(h.fig);
try
	set(hManager.WindowListenerHandles, 'Enable', 'off');  % HG1
catch
	[hManager.WindowListenerHandles.Enabled] = deal(false);  % HG2
end






% ============================================================
% ADD TEXT
% ============================================================
% ADD FRAME-NUMBER TEXT IN UPPER LEFT CORNER
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
		figsource.n = prevsource.n + N;
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
	figsource.n = N;
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
					playNextFrame()
				case 'uparrow'
					changeBrightness(.01);
				case 'downarrow'
					changeBrightness(-.01);
				case 'space'
					startStopPlayToEnd()
				case 'escape'
					closeFigure(src,evnt);
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
								setFrame(N)
							case 'uparrow'
								changeContrast(.01);
							case 'downarrow'
								changeContrast(-.01);
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
								setFrameRelative(-max(8,ceil(N/256)))
							case 'rightarrow'
								setFrameRelative(max(8,ceil(N/256)))
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
					changeBrightness( .005*scrollCount*scrollAmount);
				case {'c', 'd'} % CONTRAST
					% 					set(gca,'CLim', cast( currentLim + [-dLim dLim],'like',currentLim));
					changeContrast( .005*scrollCount*scrollAmount);
				otherwise % FRAME NUMBER
					switch scrollCount
						case -1 % SCROLL-UP
							playPreviousFrame()
							
						case 1 % SCROLL-DOWN
							playNextFrame()
							
						otherwise % MULTISCROLL
							k = getappdata(h.fig,'k');
							setFrame(k+scrollCount)
					end
			end
		end
	end
	function winClickControlFcn(src,evnt)
		persistent lastClickTic
		if ~isempty(lastClickTic)
			doubleClickDelay = toc(lastClickTic);
			fitMag = h.scrollpanapi.findFitMag();
			curMag = h.scrollpanapi.getMagnification();
			curPt = evnt.IntersectionPoint(1:2);
			% 			curPt = src.CurrentPoint; % [cx cy]
			if doubleClickDelay < .350
				switch evnt.Button
					case 1
						% 						h.scrollpanapi.setMagnificationAndCenter(1.5*curMag, curPt(1), curPt(1))
						if ~isfield(h, 'ovpanel') || isempty(h.ovpanel) || ~isvalid(h.ovpanel)
							h.ovpanel = imoverviewpanel(h.fig,h.im);
						end
						h.ovpanel.Units = 'Normalized';
						h.ovpanel.Position = [0 0 .25 .25];
						% 						h.scrollpanapi.setMagnification(max(curMag,fitMag)*1.5)
						h.scrollpanapi.setMagnificationAndCenter(max(curMag,fitMag)*1.5, curPt(1), curPt(2))
						h.ovpanel.Visible = 'on';
						h.ovpanel.ButtonDownFcn = @winClickControlFcn;
						% JavaFrame
						% Visible Visible_I VisibleMode Clipping Behavior Children Controller
						% BackgroundColor _I BackgroundColorMode
						% ForegroundColor
						
					case 2
						% 						if ~isfield(h, 'pixinfopanel') || ~ishandle(h.pixinfopanel) || ~isvalid(h.pixinfopanel)
						% 							h.pixinfopanel = impixelinfo(h.fig, h.im);
						% 						end
						% 						h.pixinfopanel.Visible = 'on';
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
		% 		drawnow
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
		s.imhandle.CData = s.f(:,:,k);
		
		if k >= s.n
			if isRunning
				stop(frameTimer)
			end
		end
		setappdata(h.fig, 'k', k);
		if ~isempty(h.text)
			h.text.String = sprintf('[%d]',k);
		end
		
		
		% 		% CHECK PLAY SPEED (APPLY SKIP IF TOO SLOW)
		% 		if frameTimer.TasksExecuted > 100 ...
		% 				&& ~isnan(frameTimer.AveragePeriod) ...
		% 				&&  isRunning()
		%
		% 			fpsRequested = 1/frameTimer.Period;
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
		s.imhandle.CData = s.f(:,:,k);
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
		s = getappdata(h.fig,'s');
		k = max(min(s.n, k),1);
		s.imhandle.CData = s.f(:,:,k);
		setappdata(h.fig, 'k', k);
		if ~isempty(h.text)
			h.text.String = sprintf('[%d]',k);
		end
	end
	function setFrameRelative(dk)
		drawnow
		s = getappdata(h.fig,'s');
		k = getappdata(h.fig,'k');
		k = max(min(s.n, k+dk),1);
		s.imhandle.CData = s.f(:,:,k);
		setappdata(h.fig, 'k', k);
		s.imhandle.CData = s.f(:,:,k);
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
			% 			hGRoot = handle(groot);
			% 			figName = 'imscplay-fig';
			% 			hGRoot.ShowHiddenHandles = 'on';
			% 			curFig = findobj(hGRoot.Children, 'Name', figName);
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
			if isRunning
				stop(frameTimer)
			end
			delete(frameTimer);
		end
		delete(h.fig)
	end
	function h = addScaledImage(im, h)
		
		% PROCESS INPUT
		if nargin < 2
			h = [];
		end
		im = squeeze(im);
		[nRows, nCols, nFrames] = size(im);
		relativeFrameSize = [[nCols nRows]./max(nRows,nCols) , 1];
		maxIm = [];
		minIm = [];
		if nFrames > 1
			maxIm = max(im,[],3);
			minIm = min(im,[],3);
			frameNum = ceil(rand*nFrames);
			im = squeeze(im(:,:,frameNum));
			if isa(im,'gpuArray')
				txtString = sprintf('Frame: %i\nClass: %s (gpuArray)',frameNum,classUnderlying(im));
			else
				txtString = sprintf('Frame: %i\nClass: %s',frameNum,class(im));
			end
		else
			if isa(im,'gpuArray')
				txtString = sprintf('Class: %s (gpuArray)',classUnderlying(im));
			else
				txtString = sprintf('Class: %s',class(im));
			end
		end
		warning('off','MATLAB:Figure:SetPosition')
		
		% IF COMPLEX SHOW ANGLE IN LOWER CMAP RANGE & MAG IN UPPER RANGE
		if ~isreal(im)
			imMag = abs(fftshift(im));
			imMag = (imMag-min(imMag(:))) ./ range(imMag(:));
			imAng = exp(angle(fftshift(im)));
			imAng = (imAng-min(imAng(:))) ./ range(imAng(:));
			im =  (imMag - imAng)/2 + .5;
		end
		
		% INITIALIZE GRAPHICS OBJECTS (WINDOW, IMAGE, AXES)
		if isempty(h)
			h.im = handle(imagesc(im));
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
			h.im = handle(imagesc(h.ax, im));
		end
		% h.ax.CLim = frameMean + [-frameStd frameStd];
		
		% SET INTENSITY LIMITS DEPENDING ON IMAGE TYPE
		try
			if islogical(im)
				clow = 0;
				chigh = 1;
			else
				if ~isempty(minIm)
					clow = oncpu(min(minIm(minIm(:)>min(minIm(:)))));
				else
					clow = oncpu(min(im(im(:)>min(im(:)))));
				end
				if ~isempty(maxIm)
					chigh = oncpu(max(maxIm( maxIm < (max(maxIm(:))))));
				else
					chigh = oncpu(max(im( im < (max(im(:))))));
				end
			end
			if isempty(clow)
				clow = min(im(:));
			end
			if isempty(chigh)
				chigh = max(im(:));
			end
			if (clow >= chigh)
				crange = getrangefromclass(oncpu(im(1)));
				clow = crange(1);
				chigh = crange(2);
			end
			if clow<chigh
				h.ax.CLim = [clow chigh];
			end
		catch me
			msg = getError(me);
			disp(msg)
		end
		
		% DEFINE CUSTOM COLORMAP (UNNAMED AT THIS JUNCTURE)
		n = 4096;
		redtrans = round(n/5);
		bluetrans = round(n/10);
		greentrans = 50;
		
		% CONSTRUCT CUSTOM COLORMAP
		chan.red = [ zeros(n-redtrans-greentrans,1) ; logspace(2, log10(n), redtrans+greentrans)'./(redtrans+greentrans) ];%log10(n-redtrans)
		chan.green = [zeros(greentrans,1) ; linspace(0, 1, n-greentrans-redtrans)'; fliplr(linspace(.5, 1, redtrans-1))' ; .25];
		chan.blue = [fliplr( logspace(1, 2, n-bluetrans)./250)'-log(2)/500 ; zeros(bluetrans,1)];
		cmap = max(0, min(1, [chan.red(:) chan.green(:) chan.blue(:)]));
		colormap(cmap)
		
		% EXPERIMENTAL?? MESSING WITH COLORBAR
		% 		try
		% 			if ~islogical(im)
		% 				h.cb = findobj(h.fig.Children,'Type','ColorBar');
		% 				if isempty(h.cb) %isfield(h,'cb') && ishandle(h.cb) && isvalid(h.cb)
		% 					h.cb = handle(colorbar);
		% 				end
		% 				h.cb.Ticks = linspace(clow, chigh, 10);
		% 				ticks = num2cell(cast(h.cb.Ticks, 'like',im));
		% 				h.cb.TickLabels = ticks;
		% 			end
		% 		catch me
		% 		end
		% 		h.cb.Location = 'east';
		
		% lpos = h.ax.Position(1)+h.ax.Position(3);
		% h.cb.Position(1) = lpos;
		
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
		
		assignin('base', 'hImsc', h);
		
		if nargout
			varargout{1} = h;
			% 			varargout{1} = h.im;
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






function varargout = imsc(im)

%% PROCESS INPUT
im = squeeze(im);
[nRows, nCols, nFrames] = size(im);
relativeFrameSize = [[nCols nRows]./max(nRows,nCols) , 1];
if nFrames > 1
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

%% IF COMPLEX SHOW ANGLE IN LOWER CMAP RANGE & MAG IN UPPER RANGE
if ~isreal(im)
	imMag = abs(fftshift(im));
	imMag = (imMag-min(imMag(:))) ./ range(imMag(:));
	imAng = exp(angle(fftshift(im)));
	imAng = (imAng-min(imAng(:))) ./ range(imAng(:));
	im =  (imMag - imAng)/2 + .5;
end

%% INITIALIZE GRAPHICS OBJECTS (WINDOW, IMAGE, AXES)
h.im = handle(imagesc(im));
h.ax = handle(h.im.Parent);
h.fig = handle(h.ax.Parent);

h.fig.Units = 'normalized';
h.ax.Position = [0.005 .005 .99 .99];
h.ax.PlotBoxAspectRatioMode = 'manual'; % DataAspectRatio
h.ax.PlotBoxAspectRatio = oncpu(relativeFrameSize);
h.ax.XTick = [];
h.ax.YTick = [];
h.ax.SortMethod = 'childorder';
% h.ax.CLim = frameMean + [-frameStd frameStd];

% SET INTENSITY LIMITS DEPENDING ON IMAGE TYPE
try
	if islogical(im)
		clow = 0;
		chigh = 1;
	else
		clow = oncpu(min(im(im(:)>min(im(:)))));
		chigh = oncpu(max(im( im < (max(im(:))))));
	end
	if isempty(clow)
		clow = min(im(:));
	end
	if isempty(chigh)
		chigh = max(im(:));
	end
	if (clow >= chigh)
		crange = getrangefromclass(im);
		clow = crange(1);
		chigh = crange(2);
	end
	if clow<chigh
		h.ax.CLim = [clow chigh];
	end
catch me
end

% SET RENDERER
h.fig.Renderer = 'opengl';

%% DEFINE CUSTOM COLORMAP (UNNAMED AT THIS JUNCTURE)
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

% ADD DESCRIPTIVE TEXT IN UPPER LEFT CORNER
% text(20,50,txtString);

%% EXPERIMENTAL?? MESSING WITH COLORBAR
try
	if ~islogical(im)
		imUnderCb = im(:, round(.85*size(im,2)):end);
		imMean = mean(imUnderCb(:));
		cmapIdx = max(1,min(n, round(n*(imMean-clow)/(chigh-clow))));
		meanColor = cmap(cmapIdx,:);
		cbFontColor = (max(meanColor)-meanColor)/range(meanColor); % [.5 .5 .5]
		h.cb = findobj(h.fig.Children,'Type','ColorBar');
		if isempty(h.cb) %isfield(h,'cb') && ishandle(h.cb) && isvalid(h.cb)
			h.cb = handle(colorbar);
		end
		h.cb.Ticks = linspace(clow, chigh, 10);
		ticks = num2cell(cast(h.cb.Ticks, 'like',im));
		h.cb.TickLabels = ticks;
	else
		cbFontColor = [1 1 1];
	end
	h.cb.Location = 'east';
	h.cb.Color = cbFontColor; %[cbFontColor .5];
	h.cb.FontWeight = 'bold';
	h.cb.FontSize = 8;
	h.cb.Box = 'off';
	
catch me
end

% lpos = h.ax.Position(1)+h.ax.Position(3);
% h.cb.Position(1) = lpos;

% POSITION (experimental)
h.fig.OuterPosition = [.5 .050 .5 .95];
h.fig.BackingStore = 'on';
% h.fig.MenuBar = 'none';
h.fig.DoubleBuffer = 'on';
h.fig.GraphicsSmoothing = 'on';
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


h.fig.KeyPressFcn = @keyPressControlFcn;
h.fig.WindowScrollWheelFcn = @scrollWheelControlFcn;





if nargout
	varargout{1} = h.im;
else
	assignin('base', 'h', h);
end




%% SUBFUNCTIONS
	function keyPressControlFcn(src, evnt)
		
		% 		if ~isempty(frameTimer) && isvalid(frameTimer)
		% 			isRunning = strcmpi(frameTimer.Running, 'on');
		% 		else
		% 			isRunning = false;
		% 		end
		modKeySet = evnt.Modifier;
		
		if isempty(modKeySet)
			% KEYBOARD COMMANDS (UNMODIFIED)
			switch evnt.Key
				case 'leftarrow'
					% 					playPreviousFrame()
				case 'rightarrow'
					% 					playNextFrame(src)
				case 'uparrow'
					changeBrightness(.01);
				case 'downarrow'
					changeBrightness(-.01);
				case 'space'
					% 					startStopPlayToEnd()
				case 'escape'
					% 					if isRunning
					% 						stop(frameTimer)
					% 					end
					% 					if ~isempty(frameTimer) && isvalid(frameTimer)
					% 						delete(frameTimer)
					% 					end
					delete(src)
			end
		else
			if numel(modKeySet) == 1
				modKey = modKeySet{1};
				% KEYS USED WITH SINGLEMODIFIER (CTRL, ALT, SHIFT,...)
				switch modKey
					case 'control'
						switch evnt.Key
							case 'leftarrow'
								% 								setFrame(1)
							case 'rightarrow'
								% 								setFrame(N)
							case 'uparrow'
								changeContrast(.01);
							case 'downarrow'
								changeContrast(-.01);
							case 'space'
								set(h.ax,'CLim', approximateClim(h.im.CData));
						end
						
					case 'alt'
						
						
					case 'shift'
						switch evnt.Key
							case 'leftarrow'
								% 								setFrameRelative(-max(10,fix(N/256)))
							case 'rightarrow'
								% 								setFrameRelative(max(10,fix(N/256)))
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
							% 							playPreviousFrame()
							
						case 1 % SCROLL-DOWN
							% 							playNextFrame()
							
						otherwise % MULTISCROLL
							% 							k = getappdata(h.fig,'k');
							% 							setFrame(k+scrollCount)
					end
			end
		end
	end	
	function changeBrightness(dB)
% 		s = getappdata(h.fig,'s');
		currentLim = double(get(h.ax,'CLim'));
		limRange = (currentLim(2)-currentLim(1));
		if currentLim(1) ~= 0
			newLim = cast( currentLim - limRange*dB, 'like', currentLim);
		else
			newLim = cast( currentLim .* (1 - dB), 'like', currentLim);
		end
		if any(isinf(currentLim)) || any(isinf(newLim))
			% 			s = getappdata(h.fig,'s');
			% 			lowLim = min(s.imhandle.CData(:));
			% 			highLim = max(s.imhandle.CData(:));
			lowLim = min(h.im.CData(:));
			highLim = max(h.im.CData(:));
			newLim = [lowLim highLim];
		end
		set(h.ax,'CLim', newLim);
	end
	function changeContrast(dC)
		% 		s = getappdata(h.fig,'s');
		currentLim = double(get(h.im.Parent,'CLim'));
		limRange = (currentLim(2)-currentLim(1));
		newLim = cast( currentLim + limRange.*[dC -dC], 'like', currentLim);
		if any(isinf(currentLim)) || any(isinf(newLim))
			% 			s = getappdata(h.fig,'s');
			lowLim = min(h.im.CData(:));
			highLim = max(h.im.CData(:));
			newLim = [lowLim highLim];
		end
		set(h.ax,'CLim', newLim);
	end
	function f = oncpu(f)
		if isa(f,'gpuArray')
			f = gather(f);
		end
		f = double(f);
	end

end

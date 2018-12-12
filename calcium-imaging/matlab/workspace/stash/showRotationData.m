function showRotationData(md)

%% SETUP
% Variables and Data
frameRate = md.fps;			% actual frame-rate of video
viewSpeed = 1;
frameDisplayInterval = 1;
downCounter = frameDisplayInterval;
cmap = [...
	linspace(1,1,128)' linspace(0,1,128)' linspace(0,1,128)' ;...
	linspace(1,0,128)' linspace(1,0,128)' linspace(1,1,128)'];
tailLength = round(frameRate * 60);
figUpdatePeriod = 1/(frameRate*viewSpeed);
x = smooth(double(md.x));
y = smooth(double(md.y));
dOmega = diff([0 ; smooth(md.orientation)]);
dx = diff([0 ; x ]);
dy = diff([0 ; y]);
vid = VideoReader(fullfile(md.fpath,md.fname));

%% Make Figure & Axes
hFig = figure;
set(hFig,...
	'DoubleBuffer','on',...
	'Renderer', 'openGL',...
	'Colormap',cmap);
axis([md.bowl.xbounds  md.bowl.ybounds]);
axis square
h.fig = handle(hFig);

%% Add Image
xlim = get(gca,'XLim');
ylim = get(gca,'YLim');
xvec = xlim(1):xlim(2);
yvec = ylim(1):ylim(2);
if vid.Width ~= md.frameWidth
	im = scaleVid(read(vid,1));
else
	im = read(vid,1);
end
im = im(yvec,xvec,:);
hImage = handle(image(xvec,yvec, im));
set(hImage,'AlphaDataMapping','scaled',...
	'AlphaData',.4,...
	'CDataMapping','scaled')
h.image = handle(hImage);

%% Add Line
hLine = handle(line(0,0, ...
	'Marker','none',...
	'LineStyle','-',...
	'LineWidth',.5,...
	'Color',[0 .6 0]));
set(hLine, 'XData', md.x(1:1+tailLength), 'YData',md.y(1:1+tailLength));
h.line = handle(hLine);

%% Add Patch (circle around mouse)
bodyPos = md.bodyPosition(1,:);
tailPos = md.tailPosition(1,:);
rumpPos = md.rumpPosition(1,:);
rump2body = bodyPos-rumpPos;
bowlRelativePosition = bodyPos - md.bowl.center;
[headX,headY] =  pol2cart(pi/180*md.theta(1),25);
headY = -headY;
caudalRostral = cat(1,tailPos,rumpPos,bodyPos,bodyPos+[headX headY]);
bodyCircle = circle(md.bodyPosition(1,:),...
	hypot(rump2body(1),rump2body(2)))';
hBodyPatch = handle(patch(bodyCircle(:,1),bodyCircle(:,2),'r'));
set(hBodyPatch,'FaceAlpha',.1,...
	'FaceColor','red',...
	'EdgeColor','black');
hSpineLine = handle(line('XData',caudalRostral(:,1),'YData',caudalRostral(:,2),...
	'Marker','o',...
	'MarkerSize',10,...
	'MarkerEdgeColor',[0 0 .45],...
	'LineStyle','-',...
	'BusyAction','queue',...
	'LineWidth',3,...
	'Color',[0 .2 .2]));
h.body = handle(hBodyPatch);
h.spine = handle(hSpineLine);

%% Add Text
hText = handle(text(x(1)+20, y(1)+20,...
	sprintf('TIME: %3.2g secs\nROTATION: %3.2g', 0/frameRate, md.rotation(1)),...
	'FontWeight','demi',...
	'BusyAction','cancel'));
h.text = handle(hText);

% Adjust Screen Transparency
set(gca,'ALim',[.05 1],...
	'Position',[0 0 1 1],...
	'CLim',[0 1])
h.ax = handle(gca);

% Create TIMER that updates graphic/animation
t = timer(...
	'ExecutionMode','fixedRate',...
	'Period',figUpdatePeriod,...	
	'TimerFcn', @localTimer);
h.timer = handle(t);
assignin('base','h',h);
start(t)

%% VIDEO SCALING FUNCTION
	function vidOutput = scaleVid(vidInput)
		try
			vidInSize = size(vidInput);
			oldWidth = vidInSize(2);
			resScale = md.frameWidth/oldWidth;
			% Get Video Size & Number of Frames
			if ~ismatrix(vidInput)
				if vidInSize(end) > 3 % input is multi-frame video sequence
					nFrames = vidInSize(end);
				else % input is single RGB image
					nFrames = 1;
				end
			else % input is a single frame
				nFrames = 1;
			end
			vidOutSize = [round(vidInSize(1:2).*resScale) nFrames];
			vidOutput = zeros(vidOutSize,'single');
			for k = 1:nFrames
				switch ndims(vidInput)
					case 2
						vidFrame = gpuArray(im2single(vidInput));
					case 3
						vidFrame = gpuArray(im2single(vidInput(:,:,k)));
					case 4 % Assume RGB
						vidFrame = gpuArray(im2single(vidInput(:,:,:,k)));
				end
				% Scale to 640x480
				if resScale ~= 1
					vidFrame = imresize(vidFrame,resScale);
				end
				% Convert to Grayscale Intensity Image
				if ~ismatrix(vidFrame)
					vidFrame = rgb2gray(vidFrame);
				else
					vidFrame = mat2gray(vidFrame);
				end
				% Return Frame from Video-Card
				vidOutput(:,:,k) = gather(vidFrame);
			end
		catch me
			disp(me.message)
			keyboard
		end
	end



%% ANIMATION UPDATE FUNCTION
	function localTimer(t, ~)
		try			
			if t.AveragePeriod > (frameDisplayInterval+1)*figUpdatePeriod
				frameDisplayInterval = frameDisplayInterval+1;
				return
			end
			downCounter = downCounter-1;
			if downCounter>0
				return
			else
				downCounter = frameDisplayInterval;
			end
			k = get(t,'TasksExecuted')+1;
			if k > numel(x)		% Finished
				stop(t);
				delete(t);
			else
				if k > 1			% Update Animation
					% POSITION TRAIL
					tailEnd = max([ 1 k-tailLength+1]);
					hLine.XData = x(tailEnd:k);
					hLine.YData = y(tailEnd:k);
					% TEXT
					hText.Position = [x(k)+20 y(k)-20];
					hText.String = sprintf('TIME: %0.4g secs\nROTATION: %0.3g', k/frameRate, md.rotation(k));
					% BODY-PART POSITIONS
					[headX,headY] =  pol2cart(pi/180*md.theta(k),25);
					headY = -headY;
					bodyPos = md.bodyPosition(k,:);
					tailPos = md.tailPosition(k,:);
					rumpPos = md.rumpPosition(k,:);
					rump2body = bodyPos-rumpPos;
					caudalRostral = cat(1,tailPos,rumpPos,bodyPos,bodyPos+[headX headY]);
					bodyCircle = circle(md.bodyPosition(k,:),hypot(rump2body(1),rump2body(2)))';					
					hSpineLine.XData = caudalRostral(:,1);
					hSpineLine.YData = caudalRostral(:,2);
					hBodyPatch.XData = bodyCircle(:,1);
					hBodyPatch.YData = bodyCircle(:,2);
					drawnow
					% CHECK TIMING
						% IMAGE BACKGROUND
						if vid.Width ~= md.frameWidth
							im = scaleVid(read(vid,k));
						else
							im = read(vid,k);
						end
						im = im(yvec,xvec,:);
						hImage.CData = im;
					
				end
			end
		catch me
			assignin('base','me',handle(me))
		end
	end  % localTimer



end
















% rotmat = [cosd(w) -sind(w) ; sind(w) cosd(w)];

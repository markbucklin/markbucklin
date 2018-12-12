function mouseData = getRotationData(varargin)
%
% USAGE:
%	>> mouseData = getRotationData
%	>> mouseData = getRotationData(filename)
%	>> mouseData = getRotationData(filename,filepath)
%
% If an argument is given then the argument is used as filename
% otherwise this functino gets .wmv or .avi files from current directory and calls recursively

try
	%% FIND VIDEO FILES TO PROCESS
	global SAVEBINARY
	if ~isempty(varargin)
		fname = varargin{1};
		fprintf(['\n ==========================\n',...
			'GETROTATIONDATA.M\n\tProcessing: %s'],fname)
		if nargin>1
			fpath = varargin{2};
		else
			fpath = pwd;
		end
	else
		% Check current directory
		d = dir;
		d =  d(~[d.isdir]);
		dwmv = strfind({d.name},'.wmv');
		davi = strfind({d.name},'.avi');
		% If empty query user for directory
		if isempty([davi{:}]) && isempty([dwmv{:}])
			fpath = uigetdir(pwd,'Select folder with video files (.wmv or .avi) to process');
			d = dir(fpath);
			d =  d(~[d.isdir]);
			dwmv = strfind({d.name},'.wmv');
			davi = strfind({d.name},'.avi');
		else
			fpath = pwd;
		end
		% Process all video files in directory by calling function recursively
		m=1;
		for n=1:numel(d)
			if ~isempty(dwmv{n})
				vidfile(m) = d(n);
				m=m+1;
			else
				if ~isempty(davi{n})
					vidfile(m) = d(n);
					m=m+1;
				end
			end
		end
		if matlabpool('size')==0
			matlabpool open
		end
		for m=1:numel(vidfile)
			mouseData(m) = getRotationData(vidfile(m).name,fpath);
		end
		matlabpool close
		return
	end
	
	
	%% PRELIMINARY
	bowl_threshold = .4;
	tail_eroder = 6;
	pixarea_exclude = 100; %previously 180, 50
	frame_batch_max = 180; % previously 60
	background_subtracted_threshold = .5;
	bodySE = strel('disk',3*round(tail_eroder/3));
	
	%% Create VideoReader Object
	vidReader = VideoReader(fullfile(fpath,fname));
	firstFrame = scaleVid(read(vidReader,1));
	[frameHeight, frameWidth] = size(firstFrame);
	frame_batches = floor(vidReader.NumberOfFrames /frame_batch_max);
	pixelsum_threshold = bowl_threshold*frameHeight;
	fps = vidReader.NumberOfFrames/vidReader.Duration;
	
	
	%% Preallocate data storage array
	rawData = zeros([frameHeight frameWidth frame_batch_max],'single');
	
	%% Collect sample of frames spaced over experiment for reference
	sample_start = min([30 vidReader.NumberOfFrames]);
	sampleIndices = linspace(sample_start, vidReader.NumberOfFrames, frame_batch_max);
	tic
	m=1;
	for n=floor(sampleIndices)
		tic
		rawData(:,:,m) =scaleVid(read(vidReader,n));
		m=m+1;
		fprintf('\t\t(%f seconds)\n',toc)
	end
	
	%% Remove Background
	maxback = max(rawData,[],3);
	meanback = mean(rawData,3);
	background = imadjust(medfilt2(maxback,[10 14]));
	rawDataBackSubtract = imabsdiff(rawData, repmat(background,[1 1 size(rawData,3)]));
	
	%% Identify Bowl in Image
	se1 = strel('line',5,0);
	se2 = strel('line',5,90);
	bowl.closedImage = imadjust(imclose(background,strel('disk',25)));
	bw = edge(bowl.closedImage);
	bw = bwareaopen(imdilate(bw,[se1 se2]),150);
	ws = watershed(bw);
	bowlshedval = ws(480/2, 640/2);
	ws(ws~=bowlshedval) = 0;
	ws = logical(ws);
	xprof = sum(ws,1) > 480*.1;
	yprof = sum(ws,2) > 640*.1;
	bowl.xbounds = [find(xprof,1,'first') find(xprof,1,'last')];
	bowl.ybounds = [find(yprof,1,'first') find(yprof,1,'last')];
	bowl.diameter = diff(bowl.xbounds);
	bowl.radius = round(bowl.diameter/2);
	bowl.center = round([median(bowl.xbounds) median(bowl.ybounds)]);
	x = (1:frameWidth) - bowl.center(1)-1;
	y = (1:frameHeight) - bowl.center(2)-1;
	[cx,cy] = pol2cart(0:pi/200:2*pi,bowl.radius);
	bowlMask = roipoly(x,y,background,cx,cy);
	
	
	%% Determine approximate size of mouse (including tale)
	rawDataBackSubtract(repmat(~bowlMask,[1 1 size(rawDataBackSubtract,3)])) = 0;
	rawData(repmat(~bowlMask,[1 1 size(rawDataBackSubtract,3)])) = 0;
	rawBinary = rawDataBackSubtract > background_subtracted_threshold;
	fprintf('\nProcessing reference frames...\n')
	extentF = frameHeight;
	for fn = size(rawBinary,3):1
		% removes small objects, leaving binary mouse
		binaryMouse = bwareaopen(rawBinary(:,:,fn),pixarea_exclude);
		imagesc(binaryMouse)
		radF = sum(radon(uint8(binaryMouse),0:179),2) > 1;
		extentF(fn) = find(radF,1,'last') - find(radF,1,'first');
	end
	mouse_radius = round(max(extentF)/2);
	
	%% Use size and ROI Circle around mouse to get points
	binaryMouse = bwareaopen(rawBinary(:,:,1),pixarea_exclude);
	mouseCC = bwconncomp(binaryMouse);
	mouseStats = regionprops(mouseCC,'All');
	%     bcCirc = circle(mouseStats.Centroid, mouse_radius/2);
	%     bodyCenterROI = roipoly(binaryMouse,bcCirc(1,:),bcCirc(2,:));
	
	%% PROCESS ALL DATA IN BATCHES
	batchData = struct.empty(frame_batches,0);
	frameStart = 1:frame_batch_max:frame_batch_max*frame_batches-1;
	saveBinaryLocal = SAVEBINARY;
	rawData = [];
	parfor n = 1:frame_batches
		k = frameStart(n);
		localPixExcludeParameter = pixarea_exclude;
		m=k:k+frame_batch_max-1;
		fprintf('\tProcessing frames: %g-%g', m(1), m(end))
		tic
		% LOAD BATCH OF FRAMES AND MAKE BINARY
		rawData = scaleVid(read(vidReader,[m(1) m(end)]));
		rawData = imabsdiff(rawData, repmat(background,[1 1 size(rawData,3)]));
		rawData(repmat(~bowlMask,[1 1 size(rawData,3)])) = 0;
		% INITIATE POSITION VARIABLES
		rawBinary = rawData > background_subtracted_threshold;
		bodyXY = zeros(frame_batch_max,2,'single');
		bodyTheta = zeros(frame_batch_max,1,'single');
		tailXY = zeros(frame_batch_max,2,'single');
		rumpXY = zeros(frame_batch_max,2,'single');
		mouseProps = cell.empty(frame_batch_max,0);
		bodyBinary = false(size(rawBinary(:,:,1)));
		tailBinary = false(size(rawBinary(:,:,1)));
		for fn = 1:size(rawBinary,3)
			binaryMouse = imclose(bwareaopen(rawBinary(:,:,fn),localPixExcludeParameter),strel('disk',10));	% remove small objects and fill in holes
			% 			mouseCC = bwconncomp(binaryMouse);
			%             mouseRP = regionprops(mouseCC,'All');
			% 			binaryMouse = false(size(binaryMouse));
			% 			binaryMouse(mouseCC.PixelIdxList{1}) = true;
			% FIND BODY POSITION
			binaryBody = imdilate( imerode(binaryMouse,bodySE), bodySE); % remove tail, leave body
			x = round(median(find(sum(binaryBody,1))));
			y = round(median(find(sum(binaryBody,2))));
			body = [x y];
			% FIND TAIL POSITION
			binaryTail = bwareaopen(xor(binaryMouse,binaryBody), localPixExcludeParameter);	% tail without the body
			try
				bcCirc = circle(body, mouse_radius/2);
				bodyCenterROI = roipoly(binaryMouse,bcCirc(1,:),bcCirc(2,:));
				binaryTail = and(binaryTail,bodyCenterROI);
			catch me
				fprintf('failedbodycenterroi: %s', me.message)
				
			end
			while ~any(binaryTail(:))
				localPixExcludeParameter = localPixExcludeParameter-1;
				binaryTail = bwareaopen(xor(binaryMouse,binaryBody), localPixExcludeParameter);
			end
			x = round(median(find(sum(binaryTail,1))));
			y = round(median(find(sum(binaryTail,2))));
			tail = [x y];
			% FIND RUMP POSITION (Tail-Body Connection)
			binaryRump = imdilate(binaryBody,bodySE) & imdilate(binaryTail,bodySE);
			rump = [round(median(find(sum(binaryRump,1)))) , round(median(find(sum(binaryRump,2))))];
			% CALCULATE ORIENTATION
			[thetaTail,rhoTail] = cart2pol(body(1)-tail(1), -(body(2)-tail(2)));
			[thetaRump,rhoRump] = cart2pol(body(1)-rump(1), -(body(2)-rump(2)));
			% 			rho = mean([rhoTail,rhoRump]);
			rho = rhoRump;
			if rho < mouse_radius*1.5 && rho > mouse_radius/10 %was rho > mouse_radius/10
				% 				theta = mean([thetaTail,thetaRump]);
				theta = thetaRump;
				bodyTheta(fn,1) = theta*180/pi;
			else
				bodyTheta(fn,1) = NaN;
			end
			% STORE DATA IN ARRAY FOR EACH BATCH
			bodyXY(fn,:) = body;
			tailXY(fn,:) = tail;
			rumpXY(fn,:) = rump;
			%             mouseProps{fn} = mouseRP;
			if ~isempty(saveBinaryLocal)
				bodyBinary(:,:,fn) = binaryBody;
				tailBinary(:,:,fn) = binaryTail;
			end
			% 			imshow(double(cat(3,binaryBody,binaryTail,binaryRump))), dbcont
		end
		% STORE DATA FROM EACH BATCH IN A STRUCTURE-ARRAY
		batchData(n).x = bodyXY(:,1);
		batchData(n).y = bodyXY(:,2);
		batchData(n).theta = bodyTheta;
		batchData(n).bodyPosition = bodyXY;
		batchData(n).tailPosition = tailXY;
		batchData(n).rumpPosition = rumpXY;
		if ~isempty(saveBinaryLocal)
			batchFrameStack(n).binaryBody = bodyBinary;
			batchFrameStack(n).binaryTail = tailBinary;
		end
		%         batchData(n).mouseStats = mouseProps;
		batchtime = toc;
		fprintf('\t\t%f seconds (%f frames/sec)\n',batchtime,frame_batch_max/batchtime)
	end
	
	%% SAVE DATA
	batchFields = fields(batchData);
	for n=1:numel(batchFields)
		mouseData.(batchFields{n}) = cat(1,batchData(:).(batchFields{n}));
	end
	if ~isempty(SAVEBINARY)
		batchFields = fields(batchFrameStack);
		for n=1:numel(batchFields)
			mouseData.(batchFields{n}) = cat(3,batchFrameStack(:).(batchFields{n}));
		end
	end
	while any(isnan(mouseData.theta))
		blankval = find(isnan(mouseData.theta),1,'first');
		if blankval > 1
			mouseData.theta(blankval) = mouseData.theta(blankval-1);
		else
			mouseData.theta(1) = mouseData.theta(find(~isnan(mouseData.theta),1,'first'));
		end
	end
	% Window-Sizes for Moving-Average  Filters
	mouseData.fps = fps;
	winsize_halfsecond = 2*(round(.5*mouseData.fps)/2)+1;  
	winsize_onesecond = 2*(round(1*mouseData.fps)/2)+1;  
	winsize_twosecond = 2*(round(2*mouseData.fps)/2)+1;
	winsize_fivesecond = 2*(round(5*mouseData.fps)/2)+1;
	% Build Output Data Structure
	savename = fname(1:(strfind(fname,'.wmv')-1));
	savename(isspace(savename)) = '_';
	mouseData.savename = savename;
	mouseData.fname = fname;
	mouseData.fpath = fpath;
	mouseData.t = linspace(1/fps, vidReader.Duration, numel(mouseData.x));	
	mouseData.dx = diff([mouseData.x(1) ; mouseData.x(:)]);
	mouseData.dy = diff([mouseData.y(1) ; mouseData.y(:)]);
	mouseData.dtheta = diff([mouseData.theta(1); mouseData.theta]);
	mouseData.orientation = cumsum(-180*round(double(mouseData.dtheta)/180))+mouseData.theta;
	mouseData.orientation = smooth(mouseData.orientation,winsize_halfsecond,'moving');
	mouseData.rotation = mouseData.orientation/360;
	mouseData.rotation = mouseData.rotation - mouseData.rotation(1);
	mouseData.frameWidth = frameWidth;
	mouseData.bowl = bowl;
	mouseData.background = background;
	mouseData.numFrames = length(mouseData.x);
	mouseData.framePeriod = 1/fps;
	mouseData.laserOnFrame = round(2*60*fps+1);
	mouseData.laserOffFrame = round(4*60*fps+1);
	mouseData.pixPerCm = mouseData.bowl.diameter/30.48;
	
	
	% PERIODS of AMBULATION, IMMOBILITY, ROTATION
	mouseData.ambulation.cmPerSec = hypot(mouseData.dx,mouseData.dy)/mouseData.framePeriod./mouseData.pixPerCm;  % difference of squares
	mouseData.ambulation.halfSecMovAvg = smooth(mouseData.ambulation.cmPerSec,winsize_halfsecond,'moving'); % formerly 'smambulation'
	ambulationOverThresh = mouseData.ambulation.halfSecMovAvg > 2;
	ambulationUnderThresh = mouseData.ambulation.halfSecMovAvg < 1.5; % formerly called 'immobulationPeriods'
	halfwinsize = round(2.5*mouseData.fps); % 5-second window
	fiveSecRotationThresh = 180;
	for k = 1:mouseData.numFrames		
		winOrient = mouseData.orientation(max(1,k-halfwinsize):min(mouseData.numFrames,k+halfwinsize));
		winOrient = winOrient - winOrient(1);
		leftRot = abs(max(winOrient));
		rightRot = abs(min(winOrient));
		if range(winOrient) > fiveSecRotationThresh;
			if leftRot/rightRot >= 4 % is rotation in a 5-second window 4x in one direction relative to the other
				mouseData.ambulation.performingRotation(k) = -1;
			elseif rightRot/leftRot >= 4
				mouseData.ambulation.performingRotation(k) = 1;
			else
				mouseData.ambulation.performingRotation(k) = 0;
			end
		else
			mouseData.ambulation.performingRotation(k) = 0;
		end
	end
	p = round(2*60*fps);
	mouseData.ambulation.analysisPeriods = {'pre', 'laser', 'post1', 'post2', 'post3'};		
	for expPhase = 1:5
		f1 = 1 + p*(expPhase-1);
		f2 = max(p*expPhase,mouseData.numFrames);
		nf = f2-f1+1;
		% Translation
		ambf = sum(ambulationOverThresh(f1:f2));
		mouseData.ambulation.mobileRatio(expPhase) = ambf/nf;
		immobf = sum(ambulationUnderThresh(f1:f2));
		mouseData.ambulation.immobileRatio(expPhase) = immobf/nf;
		% Rotation
		rrotf = sum(mouseData.ambulation.performingRotation(f1:f2) == 1);
		lrotf = sum(mouseData.ambulation.performingRotation(f1:f2) == -1);
		mouseData.ambulation.rightRotationRatio(expPhase) = rrotf/nf;
		mouseData.ambulation.leftRotationRatio(expPhase) = lrotf/nf;
	end
		
	
	
	
	save(fullfile(fpath,[savename,'.mat']),'mouseData','-v6')
catch me
	save failedset
	disp(me.message)
	keyboard
end












%% Video Scaling Function

function vidOutput = scaleVid(vidInput)
try
	scaled_frame_width = 640;
	vidInSize = size(vidInput);
	oldWidth = vidInSize(2);
	resScale = scaled_frame_width/oldWidth;
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
				%             case 2
				%                 vidFrame = im2single(vidInput);
				%             case 3
				%                 vidFrame = im2single(vidInput(:,:,k));
				%             case 4 % Assume RGB
				%                 vidFrame = im2single(vidInput(:,:,:,k));
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




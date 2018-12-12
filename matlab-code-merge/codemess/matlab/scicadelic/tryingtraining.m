

%%
TL = scicadelic.TiffStackLoader;
SC = scicadelic.StatisticCollector;
CE1 = scicadelic.LocalContrastEnhancer('BackgroundFrameSpan', 1,'LpFilterSigma',32);
% CE1 = scicadelic.LocalContrastEnhancer('BackgroundFrameSpan', 256,'LpFilterSigma',31);
% CE2 = scicadelic.LocalContrastEnhancer('BackgroundFrameSpan', 5, 'LpFilterSigma',5);
MC = scicadelic.RigidMotionCorrector;
% BGR = scicadelic.BackgroundRemover;% 	gdata = step(BGR, gdata);
RG = scicadelic.RoiGenerator('MaxExpectedDiameter',30, 'TemporalFilterSpan',10,...
	'MinRoiPixArea', 30, 'MaxRoiPixArea',550);
setBufferSize(RG, 32);
TL.UsePct = true;
setup(TL)
% doTrain = false;
% 
% if doTrain
% 	nTrain = 128; traindata = zeros([TL.FrameSize,nTrain], TL.InputDataType);
% 	for n = 1:TL.NFiles
% 		setCurrentFile(TL,n)
% 		for k=1:nTrain
% 			traindata(:,:,k,n) = step(TL);
% 		end
% 	end
% 	traindata = reshape(traindata, TL.FrameSize(1), TL.FrameSize(2), []);
% 	gdatabuf = gpuArray(traindata);
% 	
% 	for k=1:nTrain
% 		gdata = gpuArray(gdatabuf(:,:,k));
% 		gdata = step(CE1,gdata);
% 		[gdata, motionInfo] = step(MC,gdata);
% 		% 	gdata = step(CE2,gdata);
% 		step(SC, gdata);
% 		gdatabuf(:,:,k) = gdata;
% 	end
% 	
% 	RG.UseInteractive = true;
% 	tune(RG, gdatabuf);
% 	
% 	
% 	setCurrentFile(TL, 1);
% 	setCurrentFrame(TL, 1);
% end


%%



bufferSize = 16;%32
N = TL.NumFrames;
n=0;
frameSize = TL.FrameSize;
datatype = TL.InputDataType;
% data = zeros([frameSize N], 'uint16');
info(N).frame = struct.empty();
% info(N).motion = struct.empty();
gdatabuf = gpuArray.zeros([frameSize bufferSize],datatype);



% SAVE OUTPUT
uniqueFileName = [strtok(TL.FileName{1},'().'), ' ',datestr(now,'ddmmmyyyy_HHMM')];
fdir = [TL.FileDirectory, 'Output ', uniqueFileName,filesep];
mkdir(fdir)
fname = [fdir,'processedvideooutput','.bin'];
fid = fopen(fname, 'Wb');
% WAITBAR
h = waitbar(0,TL.FileDirectory);

tstart = hat;
while n<=N
	
	g=1;t(g)=hat;
	n=n+1; waitbar(n/N,h);
	k = rem(n-1,bufferSize)+1;
	
	% LOAD --------------------
	[cdata, frameInfo] = step(TL);%STEP-1
	g=g+1;t(g)=hat;fprintf('\tS%i: %-03.4gms\t',g-1,1000*(t(g)-t(g-1)));

	% PROCESS ------------------
	gdata = gpuArray(cdata); % STEP-2
	g=g+1;t(g)=hat;fprintf('\tS%i: %-03.4gms\t',g-1,1000*(t(g)-t(g-1)));
	
	gdata = step(CE1,gdata); % STEP-3
	g=g+1;t(g)=hat;fprintf('\tS%i: %-03.4gms\t',g-1,1000*(t(g)-t(g-1)));
	
	% 	[gdata, motionInfo] = step(MC,gdata); % STEP-4
	% 	g=g+1;t(g)=hat;fprintf('\tS%i: %-03.4gms\t',g-1,1000*(t(g)-t(g-1)));
		
	if (n<1000) || (k==round(rand*bufferSize))
		step(SC, gdata); % STEP-5		
	end
	g=g+1;t(g)=hat;fprintf('\tS%i: %-03.4gms\t',g-1,1000*(t(g)-t(g-1)));	
		
	step(RG, gdata); % STEP-6
	g=g+1;t(g)=hat;fprintf('\tS%i: %-03.4gms\t',g-1,1000*(t(g)-t(g-1)));
	
	% RETRIEVE -----------------
	info(n).frame = frameInfo; % STEP-7
% 	info(n).motion = motionInfo;
	gdatabuf(:,:,k) = gdata;	
	if k>=bufferSize
		idx = (n-bufferSize+1):n;
		 databuf = gather(gdatabuf);
		 fwrite(fid, databuf, 'uint16');
		% 		data(:,:,idx) = gather(gdatabuf);
	end
	g=g+1;t(g)=hat;fprintf('\tS%i: %-03.4gms\n',g-1,1000*(t(g)-t(g-1)));
	
	if mod(n,20) == 0
		fprintf('20 FRAMES in %-03.2gs\n\n',hat-tstart);
		tstart = hat;
	end
end

% GET RESIDUAL
if k>0
	% 	idx = (n-k+1):n;
	databuf = gather(gdatabuf(:,:,1:k));
	fwrite(fid, databuf, 'uint16');
	% 		data(:,:,idx) = gather(gdatabuf);
	% 	data(:,:,idx) = gather(uint8((255/dataMax).*single(gdatabuf(:,:,1:k))));
end
fclose(fid);
close(h)


% GATHER INFORMATION
info = unifyStructArray(info);
save(fullfile(fdir,['FRAME-INFO (time and motion) ',uniqueFileName]), 'info','-v6')


% PROPS FROM STATISTIC COLLECTOR
statprops = properties(SC);
for k=1:numel(statprops)
	fn = statprops{k};
	val = SC.(fn);
	if isa(val,'gpuArray')
		stat.(fn) = gather(val);
	end
end
save(fullfile(fdir,['PIXEL-STATS ',uniqueFileName]), 'stat','-v6')



CC = RG.ConnComp;
save(fullfile(fdir,['CONNECTED-COMPONENTS ',uniqueFileName]), 'CC','-v6')

% load('CONNECTED-COMPONENTS - half1.mat')
% load('CONNECTED-COMPONENTS - half2.mat')
% load('CONNECTED-COMPONENTS - half3.mat')
% CC = cat(1, ccfirsthalf(:), ccsecondhalf(:), ccthirdhalf(:));
% clearvars -except CC
% frameSize = [1024 1024];


parfor k=1:numel(CC)
	% 	rp =  regionprops(CC(k),...
	% 		'Centroid', 'BoundingBox','Area',...
	% 		'PixelIdxList',...
	% 		'Image');
	lm = labelmatrix(CC(k));
	chunkSize = size(lm,3);
	bufSum(:,:,k) = sum(uint16(lm>0), 3);
	bw = bufSum(:,:,k) >= max(1,chunkSize/10);
	RP{k} = regionprops(bw,... %sum(uint16(logical(lm)),3)>ceil(bufferSize/2)
		'Centroid', 'BoundingBox','Area',...
		'PixelIdxList')
	% 	RP{k} = regionprops(bw,... %sum(uint16(logical(lm)),3)>ceil(bufferSize/2)
	% 		'Centroid', 'BoundingBox','Area',...
	% 		'PixelIdxList',...
	% 		'Image',...
	% 		'EquivDiameter',...
	% 		'MajorAxisLength', 'MinorAxisLength', 'Orientation', 'Eccentricity');
	% 	frames{k} = (0:chunkSize) + chunkSize*k;
end
rps = cat(1,RP{:});
save(fullfile(fdir,['REGION-PROPS ',uniqueFileName]), 'rps','-v6')

% parfor k=1:numel(RP)
% 	frms = frames{k};
% 	for kr = 1:numel(RP{k}
% 		
rpchunkcs = cumsum(cellfun('length',RP));% assigning frames from chunks, but this way of doing it is very unclear
frameNums = {CC.Frames};
parfor k=1:numel(rps)
	chunkIdx = min(nnz(rpchunkcs <= k) + 1, numel(frameNums));
	sfroi(k) = RegionOfInterest(rps(k), 'FrameSize',frameSize, 'Frames',frameNums{chunkIdx}');
end

R = reduceRegions(sfroi);
if isempty(R)
	R = reduceSuperRegions(sfroi);
else
	R = reduceSuperRegions(R);
end
save(fullfile(fdir,['ROI-no-trace',uniqueFileName]), 'R')


% part = partitionByLocationDensity(sfroi);
% mpart = part(cellfun('length',part)>2);
% for k=1:numel(mpart)
% 	locR = mpart{k};
% 	locR = locR(isvalid(locR));
% 	redObj{k} = reduceSuperRegions(locR);
% end


% 
% cxy = cat(1,sfroi.Centroid);
% 
% gridSpace = 8;
% 
% idx = gridSpace/2:gridSpace:1024;
% h3 = bsxfun(@and,...
% 	(abs(bsxfun(@minus, cxy(:,1), idx(:)')) < gridSpace+1) ,...
% 	(abs(bsxfun(@minus, cxy(:,2), reshape(idx, 1,1,[]))) < gridSpace+1));
% 
% imagesc(squeeze(sum(h3,1)))
% 
% hGridSum = squeeze(sum(h3,1));
% [gridNum, gridIdx] = sort(hGridSum(:),'descend');
% groups = cell.empty(numel(gridIdx),0);
% [gRow,gCol] = ind2sub(frameSize, gridIdx);
% 
% h3r = reshape(h3, size(h3,1),[]);
% 
% for k=1:numel(gridIdx)
% 	groups{k} = sfroi( h3r(:,gridIdx(k)) );
% end
% 
% groups = groups(~cellfun('isempty',groups));
% numInGroup = cellfun(@numel, groups);
% lonelyGroups = groups(numInGroup == 1);
% pairGroups = groups(numInGroup == 2);
% groups = groups(numInGroup >= 3);
% 
% numBefore = zeros(size(groups(:)));
% numAfter = zeros(size(groups(:)));
% parfor k=1:numel(groups)
% 	roiGroup = groups{k};
% 	roiGroup = roiGroup(isvalid(roiGroup));
% 	ng = numel(roiGroup)
% 	numBefore(k) = ng;
% 	if ng > 1
% 		rg = reduceSuperRegions(roiGroup);
% 		numAfter(k) = numel(rg);
% 		Rmerged{k,1} = rg;
% 	elseif ng == 1
% 		rg = roiGroup;
% 		numAfter(k) = numel(rg);
% 		Rmerged{k,1} = rg;
% 	end
% end
% 
% R = cat(1,Rmerged{:});
% R = R([isvalid(R)]);
% R = R([R.Area] < 1000);
% 
% 
% 
% R = reduceSuperRegions(sfroi);

release(RG)
release(MC)
release(SC)
% release(TL)
release(CE1)


setCurrentFrame(TL, 1);
firstFrame = step(TL);
data(:,:,N) = firstFrame;
data(:,:,1) = firstFrame;
k=1;
while ~isDone(TL)
	k=k+1;
	data(:,:,k) = step(TL);
end
R.makeTraceFromVid(data);
save(fullfile(fdir,['ROI',uniqueFileName]), 'R')


% 
% 
% % PLAY VID
% lm = labelmatrix(CC(1));
% for k=2:numel(CC)
% 	lm = cat(3, lm, uint8(labelmatrix(CC(k))));
% end
% vid = vision.VideoPlayer;
% k=6;
% while k < size(lm,3)
% 	% 	fac =255/max(max(lm(:,:,k)));
% 	step(vid, cat(3,...
% 		250*uint8( lm(:,:,k+1)|lm(:,:,k)),...
% 		data(:,:,k) ,...
% 		200*uint8( lm(:,:,k)&lm(:,:,k-5))));
% 	k=k+1;
% end

% vid = zeros([frameSize, 3, size(data,3)],'uint8');
% vid(:,:,2,:) = uint8(300*(single(data)-single(min(data(:))))./single(range(data(:))));
% vid(:,:,1,1:size(lm,3)) = 235.*uint8(logical(lm));
% vid(:,:,3,1:size(lm,3)) = 200.*uint8(lm == circshift(lm, 5,3));



%%
%

% isGrouped = false(numel(sfroi),1);
% R = RegionOfInterest.empty(0,1);
% nRoi = 0;
% for k=1:numel(sfroi)
% 	if ~isGrouped(k)
% 		idx = find(~isGrouped);
% 		validRoi = sfroi(~isGrouped);
% 		closeCenters = centroidSeparation(sfroi(k),validRoi) < 20;
% 		shouldGroup = ~isGrouped;
% 		shouldGroup(idx(closeCenters)) = true;
% 		roiGroup = sfroi(shouldGroup);
% 		nRoi = nRoi+1;
% 		rgroup{k} = roiGroup;
% 		if nnz(shouldGroup) > 1
% 			R(nRoi) = merge(roiGroup);
% 		elseif nnz(shouldGroup) == 1
% 			R(nRoi) = roiGroup;
% 		end
% 		isGrouped(shouldGroup) = true;
% 	end
% end
%
%
%


TL = scicadelic.TiffStackLoader;
SC = scicadelic.StatisticCollector;
CE1 = scicadelic.LocalContrastEnhancer('BackgroundFrameSpan', 32,'LpFilterSigma',5);
% CE1 = scicadelic.LocalContrastEnhancer('BackgroundFrameSpan', 256,'LpFilterSigma',31);
% CE2 = scicadelic.LocalContrastEnhancer('BackgroundFrameSpan', 5, 'LpFilterSigma',5);
MC = scicadelic.RigidMotionCorrector;
% BGR = scicadelic.BackgroundRemover;
obj = scicadelic.RoiGenerator;
setup(TL)


% N=5000;
bufferSize = 64;
N = TL.NFrames;
n=0;
frameSize = TL.FrameSize;
datatype = TL.InputDataType;
data = zeros([frameSize N], 'uint8');
info(N).frame = struct.empty();
% info(N).motion = struct.empty();
gdatabuf = gpuArray.zeros([frameSize bufferSize],datatype);

dataMax = 20000;

h = waitbar(0,TL.FileDirectory);
while n<=N
	n=n+1; waitbar(n/N,h);
	k = rem(n-1,bufferSize)+1;
	
	% LOAD
	[cdata, frameInfo] = step(TL);
	% PROCESS
	gdata = gpuArray(cdata);
	gdata = step(CE1,gdata);
	[gdata, motionInfo] = step(MC,gdata);
	% 	gdata = step(CE2,gdata);
	step(SC, gdata);
	% 	gdata = step(BGR, gdata);
	step(obj, gdata);
	
		
	info(n).frame = frameInfo;
	info(n).motion = motionInfo;
	
	
	gdatabuf(:,:,k) = gdata;
	if k>=bufferSize
		idx = (n-bufferSize+1):n;
		data(:,:,idx) = gather(uint8((255/dataMax).*single(gdatabuf)));
	end
	
	
end
if k>0
	idx = (n-k+1):n;
	data(:,:,idx) = gather(uint8((255/dataMax).*single(gdatabuf(:,:,1:k))));
end
info = unifyStructArray(info);
close(h)

uniqueFileName = [strtok(TL.FileName{1},'().'), ' ',datestr(now,'ddmmmyyyy_HHMM')];
fdir = [TL.FileDirectory, 'Output ', uniqueFileName,filesep];
mkdir(fdir)
% PROPS FROM STATISTIC COLLECTOR
statprops = properties(SC);
for k=1:numel(statprops)
	fn = statprops{k};
	val = SC.(fn);
	if isa(val,'gpuArray')
		stat.(fn) = gather(val);
	end
end
save(fullfile(fdir,['Stats ',uniqueFileName]), 'stat','-v6')



CC = obj.ConnComp;
parfor k=1:numel(CC)	
	% 	rp =  regionprops(CC(k),...
	% 		'Centroid', 'BoundingBox','Area',...
	% 		'PixelIdxList',...
	% 		'Image');	
	lm = labelmatrix(CC(k));
	bufSum(:,:,k) = sum(lm>0, 3);
	bw = bufSum(:,:,k) >= 1;
	RP{k} = regionprops(bw,... %sum(uint16(logical(lm)),3)>ceil(bufferSize/2)
		'Centroid', 'BoundingBox','Area',...
		'PixelIdxList',...
		'Image',...
		'EquivDiameter',...
		'MajorAxisLength', 'MinorAxisLength', 'Orientation', 'Eccentricity');	
end
rps = cat(1,RP{:});
parfor k=1:numel(rps)
	sfroi(k) = RegionOfInterest(rps(k), 'FrameSize',frameSize);
end
R = reduceRegions(sfroi);
R.makeTraceFromVid(data);
save(fullfile(fdir,['ROI ',uniqueFileName]), 'R')




% PLAY VID
lm = labelmatrix(CC(1));
for k=2:numel(CC)
	lm = cat(3, lm, uint8(labelmatrix(CC(k))));
end
vid = vision.VideoPlayer;
k=6;
while k < size(lm,3)
	% 	fac =255/max(max(lm(:,:,k)));
	step(vid, cat(3,...
		200*uint8( lm(:,:,k+1)|lm(:,:,k)),...
		data(:,:,k) ,...
		200*uint8( lm(:,:,k)&lm(:,:,k-5))));
	k=k+1;  
end


% redchangevid(:,:,:,k-5) =  cat(3,...
% 		220*uint8( lm(:,:,k+1)|lm(:,:,k)),...
% 		data(:,:,k) ,...
% 		150*uint8( lm(:,:,k)&lm(:,:,k-5)));
% 	k=k+1;  







TL = scicadelic.TiffStackLoader;
CE1 = scicadelic.LocalContrastEnhancer('BackgroundFrameSpan', 512,'LpFilterSigma',31);
MC = scicadelic.RigidMotionCorrector;
CE2 = scicadelic.LocalContrastEnhancer('BackgroundFrameSpan', 1, 'LpFilterSigma',9);
BG = scicadelic.BackgroundRemover;
SC1 = scicadelic.StatisticCollector;
SC2 = scicadelic.StatisticCollector;


FGsep = vision.ForegroundDetector;
FGsep.MinimumBackgroundRatio = .75;

Blobby = vision.BlobAnalysis;
Blobby.MaximumBlobArea = 30*30;
Blobby.MinimumBlobArea = 50;
Blobby.OrientationOutputPort = true;
Blobby.EccentricityOutputPort = true;
Blobby.PerimeterOutputPort = true;
Blobby.ExcludeBorderBlobs = true;
Blobby.LabelMatrixOutputPort = true;
Blobby.MaximumCount = 200;




setup(TL)
N=TL.NumFiles;
Ksample = 100; 
sampleFileNumbers = [1 randi([2 N], [1 min(2,N-1)])];
sampledata = zeros([TL.FrameSize numel(sampleFileNumbers) Ksample],'uint16');
sampleinfo = struct.empty(numel(sampleFileNumbers),Ksample,0);
bufsize = 32;
gbuf = gpuArray.zeros([TL.FrameSize bufsize], 'uint16');
for n=1:3
currentFileIdx = sampleFileNumbers(n);
	TL.setCurrentFile(currentFileIdx)
	for k=1:Ksample
		% LOAD FRAME
		[cdata, frameInfo] = step(TL);
		sampleinfo(n,k).frame = frameInfo;
		gdata = gpuArray(cdata);
		% 1ST CONTRAST ENHANCEMENT
		gdata = step(CE1, gdata);
		% 1ST MOTION CORRECTION
		[gdata, motionInfo] = step(MC, gdata);
		sampleinfo(n,k).motion = motionInfo;
		% 2ND CONTRAST ENHANCEMENT
		gdata = step(CE2, gdata);
		% 1ST STATISTIC COLLECTION
		step(SC1, gdata);
		% BACKGROUND SUBTRACTION
		gdata = step(BG, gdata);
		% 2ND STATISTIC COLLECTION
		step(SC2, gdata);
		
		% STORE SAMPLE-DATA
		kBuf = rem(k,bufsize);
		if (kBuf > 0) 
			gbuf(:,:,kBuf) = gdata;			
			if (k==Ksample)
				idx = (k-kBuf+1):k;
				sampledata(:,:,n,idx) = gather(gbuf(:,:,1:kBuf));
			end
		else
			gbuf(:,:,bufsize) = gdata;
			idx = (k-bufsize+1):k;
			sampledata(:,:,n,idx) = gather(gbuf);		
		end			
	end
end

lockLimits(CE1);
lockLimits(CE2);
lockBackground(BG);


N=TL.NumFiles;
K = TL.NumFrames;
data = zeros([TL.FrameSize K],'uint16');
info = struct.empty(K,0);
bufsize = 32;
gbuf = gpuArray.zeros([TL.FrameSize bufsize], 'uint16');

TL.setCurrentFile(1)
k=0;
while ~isDone(TL)
	k=k+1;
	% LOAD FRAME
	[cdata, frameInfo] = step(TL);
	info(k).frame = frameInfo;
	gdata = gpuArray(cdata);
	% 1ST CONTRAST ENHANCEMENT
	gdata = step(CE1, gdata);
	% 1ST MOTION CORRECTION
	[gdata, motionInfo] = step(MC, gdata);
	info(k).motion = motionInfo;
	% 2ND CONTRAST ENHANCEMENT
	gdata = step(CE2, gdata);
	% 1ST STATISTIC COLLECTION
	step(SC1, gdata);
	
	
% 	gbuf(:,:,k) = gdata;
	data(:,:,k) = gather(gdata);
	
	% BACKGROUND SUBTRACTION
% 	gdata = step(BG, gdata);
	% 2ND STATISTIC COLLECTION
% 	step(SC2, gdata);
	
	% 	% STORE SAMPLE-DATA
	% 	kBuf = rem(k,bufsize);
	% 	if (kBuf > 0)
	% 		gbuf(:,:,kBuf) = gdata;
	% 		if (k==K)
	% 			idx = (k-kBuf+1):k;
	% 			data(:,:,idx) = gather(gbuf(:,:,1:kBuf));
	% 		end
	% 	else
	% 		gbuf(:,:,bufsize) = gdata;
	% 		idx = (k-bufsize+1):k;
	% 		data(:,:,idx) = gather(gbuf);
	% 	end
	
end



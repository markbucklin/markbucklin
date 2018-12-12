TL = scicadelic.TiffStackLoader;
CElong = scicadelic.LocalContrastEnhancer('BackgroundFrameSpan', 512);
MCrigid = scicadelic.RigidMotionCorrector;
CEshort = scicadelic.LocalContrastEnhancer('BackgroundFrameSpan', 1, 'LpFilterSigma',32);
MCnonrigid = scicadelic.NonrigidMotionCorrector;
BGmin = scicadelic.BackgroundRemover;

FGsep = vision.ForegroundDetector;
FGsep.MinimumBackgroundRatio = .95;

Blobby = vision.BlobAnalysis;
Blobby.MaximumBlobArea = 30*30;
Blobby.MinimumBlobArea = 50;
Blobby.OrientationOutputPort = true;
Blobby.EccentricityOutputPort = true;
Blobby.ExtentOutputPort = true;
Blobby.ExcludeBorderBlobs = true;

MCnonrigid.UseInteractive = true;
% doNonRigid = true;

setup(TL)
N=TL.NumFiles;
% Ksample=100;
Ksample = 1000; 
sampledata = zeros([TL.frameSize 3 Ksample],'uint16');
% sampleFileNumbers = [1 randi([2 N], [1 min(3,N)])];
% sampleinfo = struct.empty(numel(sampleFileNumbers),Ksample,0);
% sampledata = zeros([TL.frameSize N Ksample], 'uint16');
% GET SAMPLES
% nChan = numel(sampleFileNumbers);
for n=1:3:9
% 	currentFileIdx = sampleFileNumbers(n);
currentFileIdx = n;
	TL.setCurrentFile(currentFileIdx)
	for k=1:Ksample
		[cdata, frameInfo] = step(TL);
		sampleinfo(n,k).frame = frameInfo;
		gdata = gpuArray(cdata);
		gdata = step(CElong, gdata);
		% 1ST MOTION CORRECTION
		[gdata, motionInfo] = step(MCrigid, gdata);
		sampleinfo(n,k).motion = motionInfo;
		gdata = step(CEshort, gdata);
		% 2ND MOTION CORRECTION
		% 		if doNonRigid
		[gdata, motionInfo2] = step(MCnonrigid, gdata);
		sampleinfo(n,k).nrmotion = motionInfo2;
		% 		end
		gdata = step(BGmin, gdata);
		% 		sampledata(:,:,n,k) = gather(gdata);
		sampledata(:,:,n,k) = gather(gdata);
		% 	  sampledata(:,:,n,k) = gather(uint8( gdata./uint16(255)));
		% ACCUMULATE INFORMATION STRUCTURES
	end
end
lockLimits(CElong);
lockLimits(CEshort);
lockBackground(BGmin);

K = numel(TL.FullFilePath)*TL.TiffInfo(1).lastIdx;
nFramesPerFile = TL.TiffInfo(1).lastIdx;
info = struct.empty(N,K,0);
dataPre = zeros([TL.frameSize N K], 'uint8');
dataPost = zeros([TL.frameSize 1 K], 'uint8');
doNonRigid = false;

% pp = gcp;

for n=1:N
   TL.setCurrentFile(n)
   for k=1:nFramesPerFile
		% LOAD FRAME
	  [cdata, frameInfo] = step(TL);
	  info(n,k).frame = frameInfo;
	  gdata = gpuArray(cdata);
		% 1ST CONTRAST ENHANCEMENT
	  gdata = step(CElong, gdata);
	  % 	  dataPre(:,:,n,k) = gather(uint8((1/.6809).*gdata./uint16(255)));
	  % 1ST MOTION CORRECTION
	  [gdata, motionInfo] = step(MCrigid, gdata);
	  info(n,k).motion = motionInfo;
		% 2ND CONTRAST ENHANCEMENT
	  gdata = step(CEshort, gdata);
	  % 2ND MOTION CORRECTION
	  if doNonRigid
		 [gdata, motionInfo2] = step(MCnonrigid, gdata);
		 info(n,k).nrmotion = motionInfo2;
	  end
	  data8 = gather(uint8( gdata./uint16(255)));
	  dataPost(:,:,k) = data8;
	  
	  
	  bwmask = step(FGsep, data8);
	  blobs{k,n} = step(Blobby, bwmask);
	  
	  
   end
end


% rows = 1:1024;
% cols = 33:1024-32;
% saveData2Mp4(cat(2, dataMid2(rows,cols,:,:), dataPost(rows,cols,:,:)),...
%    'Z:\People\Mark\Videos\Motion Correction\scicadelic parallel moreiter.mp4');
% 
% saveData2Mp4(cat(2, dataPre(rows,cols,:,:), dataMid2(rows,cols,:,:)),...
%    'Z:\People\Mark\Videos\Ali26 scicadelic - parallel moreiter.mp4');

motion = [cat(1, info(1,:).motion), cat(1, info(2,:).motion), cat(1, info(3,:).motion)];
r.umag = [cat(1, motion(:,1).mag), cat(1, motion(:,2).mag), cat(1, motion(:,3).mag)];
r.uy = [cat(1, motion(:,1).uy), cat(1, motion(:,2).uy), cat(1, motion(:,3).uy)];
r.ux = [cat(1, motion(:,1).ux), cat(1, motion(:,2).ux), cat(1, motion(:,3).ux)];

nrmotion = [cat(1, info(1,:).nrmotion), cat(1, info(2,:).nrmotion), cat(1, info(3,:).nrmotion)];
nr.umag = [cat(1, nrmotion(:,1).mag), cat(1, nrmotion(:,2).mag), cat(1, nrmotion(:,3).mag)];
nr.uy = [cat(1, nrmotion(:,1).uy), cat(1, nrmotion(:,2).uy), cat(1, nrmotion(:,3).uy)];
nr.ux = [cat(1, nrmotion(:,1).ux), cat(1, nrmotion(:,2).ux), cat(1, nrmotion(:,3).ux)];


% motionCorrector = scicadelic.MotionCorrector;

%
% obj = scicadelic.MotionCorrector
%
% setCurrentFile(tiffLoader, 1)
%
% info(50).motion = info(1).motion;
% info(50).frame = info(1).frame;
% for k = 1:500
%    [cdata, info(k).frame] = step(tiffLoader);
%    gdata = step(contrastEnhancer, gpuArray(cdata));
%    [gdata, info(k).motion] = step(obj, gdata);
% end
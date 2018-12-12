function frameRoi = loadRoiExtract(sfroi)

frameSize = [1024 1024];
frameNum = sfroi.frame;
idx = sfroi.pixidx;
N = numel(idx);
frameRoi = RegionOfInterest.empty(N,0);


parfor kp = 1:N
   roi = RegionOfInterest.empty(1,0);
   bwmask = false(frameSize);
   bwmask(idx{kp}) = true;
   % EVALUATE CONNECTED COMPONENTS FROM BINARY 'BLOBBED' MATRIX: ENFORCE MORPHOLOGY RESTRICTIONS
   bwRP =  regionprops(bwmask,...
	  'Centroid', 'BoundingBox','Area',...
	  'Eccentricity', 'PixelIdxList','Perimeter');
   %    if isempty(bwRP)
   % 	  continue
   %    end
   roi = RegionOfInterest(bwRP);
   roi.Frames = frameNum(kp);
   roi.FrameSize = frameSize;
   frameRoi(kp) = roi;
end
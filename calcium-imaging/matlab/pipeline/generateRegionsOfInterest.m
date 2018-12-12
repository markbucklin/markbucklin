function roi = generateRegionsOfInterest(vid)
% INPUT:
%	Expects vid.cdata with cdata datatype = 'uint8'
% OUTPUT:
%	Array of objects of the 'RegionOfInterest' class, resembling a RegionProps structure
%	(Former Output)
%	Returns structure array, same size as vid, with fields
%			bwvid =
%				RegionProps: [12x1 struct]
%				bwMask: [1024x1024 logical]

% pp = parpool('local');

% SUBTRACT BACKGROUND/BASELINE IF NOT DONE ALREADY
if ~isfield(vid(1), 'backgroundMean')
  vid = normalizeVidStruct2Region(vid);
end
% APPLY SMOOTHING FILTER IN TIME DOMAIN TO STABILIZE SIGNAL
if ~isfield(vid, 'issmoothed')
  vid = tempSmoothVidStruct(vid, 2); % windowsize = 1+2(2) = 5;
end
% GET SAMPLE VIDEO STATISTICS AND DEFINE MIN/MAX ROI AREA
N = numel(vid);
frameSize = size(vid(1).cdata);
stat = getVidStats(vid);
minRoiPixArea = 50; %previously 50
maxRoiPixArea = 650; %previously 350
maxRoiEccentricity = .92;
maxPerimOverSqArea = 7; %  circle = 3.5449, square = 4 % Previousvalues: [6.5  ]
minPerimOverSqArea = 3.5;
% INITIALIZE DYNAMIC SIGNAL THRESHOLD ARRAY: ~1 STD. DEVIATION OVER MINIMUM (OVER TIME)
stdOverMin = 1.25; % formerly 1.2
signalThreshold = gpuArray( stat.Min + uint8( stat.Std.*stdOverMin ));
% RUN A FEW FRAMES THROUGH HOTSPOT FINDING FUNCTION TO IMPROVE INITIAL SIGNAL THRESHOLD
for k = fliplr(round(linspace(1,N,min(20,N))))
  [~, signalThreshold] = getAdaptiveHotspots(vid(k).cdata, signalThreshold);
end

% roi = [];
% multiWaitbar('Generate Regions of Interest',0);
% t = hat;
% GET HOTSPOT-BASED ROIS (WHENEVER SIGNAL INTENSITY EXCEEDS PIXEL-SPECIFIC THRESHOLD)
bwmask = false([frameSize N]);
for k = 1:N
  [bwmask(:,:,k), signalThreshold] = getAdaptiveHotspots(vid(k).cdata, signalThreshold);
end


frameNum = cat(1,vid.frame);
frameROI = cell(N,1);

parfor kp = 1:N
  % EVALUATE CONNECTED COMPONENTS FROM BINARY 'BLOBBED' MATRIX: ENFORCE MORPHOLOGY RESTRICTIONS
  bwRP =  regionprops(bwmask(:,:,kp),...
	 'Centroid', 'BoundingBox','Area',...
	 'Eccentricity', 'PixelIdxList','Perimeter');
  bwRP = bwRP([bwRP.Area] >= minRoiPixArea);	%	Enforce MINIMUM SIZE
  bwRP = bwRP([bwRP.Area] <= maxRoiPixArea);	%	Enforce MAXIMUM SIZE
  bwRP = bwRP([bwRP.Eccentricity] <= maxRoiEccentricity); %  Enforce PLUMP SHAPE
  bwRP = bwRP([bwRP.Perimeter]./sqrt([bwRP.Area]) < maxPerimOverSqArea); %  Enforce LOOSELY CIRCULAR/SQUARE SHAPE
  bwRP = bwRP([bwRP.Perimeter]./sqrt([bwRP.Area]) > minPerimOverSqArea); %  Enforce NON-HOLINESS (SELF-FULFILLMENT?)
  if isempty(bwRP)
	 continue
  end
  % bwvid(kp).RegionProps = bwRP;
  % bwvid(kp).bwMask = bwmask(:,:,kp);
  % FILL 'REGIONOFINTEREST' CLASS OBJECTS (several per frame)
  frameROI{kp,1} = RegionOfInterest(bwRP);
  set(frameROI{kp,1},...
	 'Frames',frameNum(kp),...
	 'FrameSize',frameSize);
end

roi = cat(1,frameROI{:});

% if isfield(vid(k),'frame')
%   frameNum = vid(k).frame(:);
% else
%   frameNum = k;
% end


% if isempty(roi)
%   roi = frameROI;
% else
%   roi = cat(1,roi, frameROI);
% end
% abort = multiWaitbar('Generate Regions of Interest',k/N);
% if abort
%   break
% end
% multiWaitbar('Generate Regions of Interest', 'Close');





% ------------ SUBFUNCTIONS -------------------
% FUNCTION TO MAKE BINARY MASK WITH ADAPTIVE THRESHOLD
  function [bw, sigThresh]  = getAdaptiveHotspots(diffImage, sigThresh)
	 coverageMaxRatio = .025; %  .01 = 10K pixels (15-30 cells?)
	 coverageMinPixels = 500; % 50
	 thresholdStep = 1;
	 % PREVENT RACE CONDITION OR NON-SETTLING THRESHOLD
	 persistent depth
	 if isempty(depth)
		depth = 0;
	 else
		depth = depth + 1;
	 end
	 if depth > 256
		warning('256 iterations exceeded')
		depth = 0;
		return
	 end
	 % USE THRESHOLD MATRIX TO MAKE BINARY IMAGE, THEN APPLY MORPHOLOGICAL OPERATIONS
	 diffImage = gpuArray(diffImage);
	 bw = diffImage > sigThresh;
	 % changed from: bw = imclose(imopen( bw, S.disk6), S.disk4);
	 bw = gather(bwmorph(bwmorph(bwmorph( bw, 'open'), 'shrink'), 'majority'));%4
	 % can also try: 'hbreak'  'shrink' 'fill'  'open' gpuArray
	 % CHECK FOR OVER/UNDER-THRESHOLDING
	 numPix = numel(bw);
	 sigThreshPix = sum(bw(:));
	 binaryCoverage = sigThreshPix/numPix;
	 if binaryCoverage > coverageMaxRatio
		sigThresh = sigThresh + thresholdStep;
		[bw, sigThresh]  = getAdaptiveHotspots(diffImage, sigThresh);
	 elseif sigThreshPix < coverageMinPixels
		sigThresh = sigThresh - thresholdStep;
		[bw, sigThresh]  = getAdaptiveHotspots(diffImage, sigThresh);
	 else
		depth = 0;
	 end
  end

end





% REGIONPROPS
%	 	'Area'              'EulerNumber'       'Orientation'
%       'BoundingBox'       'Extent'            'Perimeter'
%       'Centroid'          'Extrema'           'PixelIdxList'
%       'ConvexArea'        'FilledArea'        'PixelList'
%       'ConvexHull'        'FilledImage'       'Solidity'
%       'ConvexImage'       'Image'             'SubarrayIdx'
%       'Eccentricity'      'MajorAxisLength'
%       'EquivDiameter'     'MinorAxisLength'		---
%       'MaxIntensity'
%       'MeanIntensity'
%       'MinIntensity'
%       'PixelValues'
%       'WeightedCentroid'
% 		cc = bwconncomp(sbinary);
% 		L = labelmatrix(cc);







% BEGIN PARALLEL CLUSTER
% pp = gcp;
% pc = pp.Cluster;
% pj = pc.findJob;
% if ~isempty(pj)
%   cancel(pj);
% end

% BEGIN PARALLEL REDUCTIONS (BATCHING ACROSS TIME)
%   hRedunctionFunction = @(rkeyin) reduceKeyedRegions(rkeyin);
% % parfeval
% % genFcn = @(f1,f2) generateRegionsOfInterest(vid(f1:f2))
% %   j(kBatch) = myCluster.createJob(genFcn, 1, {k1,k2});








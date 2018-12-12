function [roi, varargout] = generateRegionsOfInterestDisplay(data)
% INPUT:
%	Expects vid.cdata with cdata datatype = 'uint8'
% OUTPUT:
%	Array of objects of the 'RegionOfInterest' class, resembling a RegionProps structure
%	(Former Output)
%	Returns structure array, same size as vid, with fields
%			bwvid =
%				RegionProps: [12x1 struct]
%				bwMask: [1024x1024 logical]




%% GET SAMPLE VIDEO STATISTICS AND DEFINE MIN/MAX ROI AREA
N = size(data,3);
frameSize = size(data(:,:,1));
stat.Min = min(data,3);
stat.Std = std(data,1,3);
stat.Mean = trimmean(data,3);
minRoiPixArea = 100;
maxRoiPixArea = 500;
maxRoiEccentricity = .92;

%% FIND CIRCLES FROM STATIC SUMMARY (not currently implemented, but seems to work well!)
% [centers,radii] = imfindcircles(stat.Max,[6 25], 'Sensitivity', .9);
% cellMask = circleCenters2Mask(centers, radii, size(data(:,:,1)));

%% PREPARE FIGURE FOR DISPLAY OF VIDEO FRAMES, OVERLAYING ROIs AS THEY ARE GENERATED
rgbImage = data(:,:,[1 round(N/2) N]);
if nargout>1
  rgbVid = zeros([size(rgbImage) N], 'uint8');
  rgbVid(:,:,:,1) = rgbImage;
end
h.im = handle(imshow(rgbImage));
h.ax = handle(gca);
h.ax.DrawMode = 'fast';
t=hat;
h.text(1) = handle(text(10,30,sprintf('Assessing TEMPORAL-REGIONAL Signal in Frame #%i (%f secs-per-frame)\n',1, hat-t), 'Color','r'));
h.text(2) = handle(text(10,60,'   (Dynamic Signal Threshold)', 'Color','b'));

%% INITIALIZE DYNAMIC SIGNAL THRESHOLD ARRAY: ~1 STD. DEVIATION OVER MINIMUM (OVER TIME)
stdOverMin = 1.2;
signalThreshold = gpuArray( stat.Min + uint8( stat.Std.*stdOverMin ));

%% DEFINE OUTPUT STRUCTURE BY MAKING FIRST CALL TO SUBFUNCTIONS WITH FIRST FRAME
[bwmask, signalThreshold] = getAdaptiveHotspots(data(:,:,1), signalThreshold);
bwvid.bwMask = bwmask;
bwvid.RegionProps = getRegionProps(bwmask);

%% PASS STRUCTURE TO 'REGIONOFINTEREST' CLASS CONSTRUCTOR: STORES ALL ROIS FOUND IN FIRST FRAME
roi = RegionOfInterest(bwvid);
set(roi, 'Frames', 1);
t = hat;
for k = 2:N
  try
	 h.text(1).String = sprintf('Assessing TEMPORAL-REGIONAL Signal in Frame #%i (%f secs-per-frame)\n',k, hat-t);
	 t = hat;
	 %% GET HOTSPOT-BASED ROIS (WHENEVER SIGNAL INTENSITY EXCEEDS PIXEL-SPECIFIC THRESHOLD)
	 [bwmask, signalThreshold] = getAdaptiveHotspots(data(:,:,k), signalThreshold);
	 bwvid.bwMask = bwmask;
	 %% EVALUATE CONNECTED COMPONENTS FROM BINARY 'BLOBBED' MATRIX: ENFORCE MORPHOLOGY RESTRICTIONS
	 bwRP = getRegionProps(bwmask);
	 bwRP = bwRP([bwRP.Area] >= minRoiPixArea);	%	Enforce minimum size
	 bwRP = bwRP([bwRP.Area] <= maxRoiPixArea);	%	Enforce maximum size
	 bwRP = bwRP([bwRP.Eccentricity] <= maxRoiEccentricity); % Enforce circular(ish) shape
	 bwvid.RegionProps = bwRP;
	 %% FILL 'REGIONOFINTEREST' CLASS OBJECTS (several per frame)
	 frameROI = RegionOfInterest(bwvid);
	 set(frameROI,'Frames',k,...
		'FrameSize',frameSize);
	 roi = cat(1,roi, frameROI);
	 %% SHOW AREAS WITH DETECTED ROIS OVERLYING VIDEO FRAME
	 rgbImage = cat(3,...
		zeros(frameSize,'uint8'),...
		data(:,:,k),...
		im2uint8(bwmask));
	 h.im.CData = rgbImage;
	 if nargout > 1
		rgbVid(:,:,:,k) = rgbImage;
	 end
	 drawnow
  catch me
	 disp(me.message)
  end
end

if nargout > 1
  varargout{1} = rgbVid;
end





%% ------------ SUBFUNCTIONS -------------------
%% FUNCTION TO MAKE BINARY MASK WITH ADAPTIVE THRESHOLD
  function [bw, sigThresh]  = getAdaptiveHotspots(diffImage, sigThresh)
	 coverageMaxRatio = .025; %  .01 = 10K pixels (15-30 cells?)
	 coverageMinPixels = 500; % 50
	 thresholdStep = 1;
	 %% PREVENT RACE CONDITION OR NON-SETTLING THRESHOLD
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
	 %% USE THRESHOLD MATRIX TO MAKE BINARY IMAGE, THEN APPLY MORPHOLOGICAL OPERATIONS
	 diffImage = gpuArray(diffImage);
	 bw = diffImage > sigThresh;
	 % changed from: bw = imclose(imopen( bw, S.disk6), S.disk4);
	 bw = gather(bwmorph(bwmorph(bwmorph( bw, 'open'), 'shrink'), 'majority'));%4 
	 % can also try: 'hbreak'  'shrink' 'fill'  'open' gpuArray
	 %% CHECK FOR OVER/UNDER-THRESHOLDING
	 numPix = numel(bw);
	 sigThreshPix = sum(bw(:));
	 binaryCoverage = sigThreshPix/numPix;
	 if binaryCoverage > coverageMaxRatio
		sigThresh = sigThresh + thresholdStep;
		h.text(2).String = sprintf('\t+ + + + Increasing signal threshold for HotSpot detection to %g\t(binary-coverage: %0.3f)\n',...
		  max(sigThresh(:)), binaryCoverage);
		[bw, sigThresh]  = getAdaptiveHotspots(diffImage, sigThresh);
	 elseif sigThreshPix < coverageMinPixels
		sigThresh = sigThresh - thresholdStep;
		h.text(2).String = sprintf('\t- - - - Decreasing signal threshold for HotSpot detection to %g\t(signal-pixels: %g)\n',...
		  max(sigThresh(:)), sigThreshPix);
		[bw, sigThresh]  = getAdaptiveHotspots(diffImage, sigThresh);
	 else
		depth = 0;
	 end
  end
%% FUNCTION FOR RETRIEVING REGIONPROPS STRUCTURE FOR BINARY INPUT
  function c = getRegionProps(sbinary)
	 c = regionprops(sbinary,...
		'Centroid', 'BoundingBox','Area',...
		'Eccentricity', 'PixelIdxList');
	 %% REGIONPROPS
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
  end
end




























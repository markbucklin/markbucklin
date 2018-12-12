function roi = generateSingleFrameRois_Display(data,frameInfo)
% GENERATESINGLEFRAMEROIS
%
% INPUT:
%	data - 3D array with datatype = 'uint8', size = [nrows, ncols, nframes]
%   frameInfo - (optional) may either be a vector of frame numbers corresponding to data, or a traditional
%					structure array with the field 'frame' containing corresponding frame-numbers.
%
% OUTPUT:
%	Array of objects of the 'RegionOfInterest' class, resembling a RegionProps structure
%	(Former Output)
%	Returns structure array, same size as vid, with fields
%			bwvid =
%				RegionProps: [12x1 struct]
%				bwMask: [1024x1024 logical]


scaleTo8 = @(X) uint8( double(X-min(X(:))) ./ (double(range(X(:)))/255));
inRgbChannel = @(X, ch) circshift(cat(3, zeros([size(X,1) size(X,2) 2],'uint8'),scaleTo8(X)), ch, 3);

% ------------------------------------------------------------------------------------------
% CHECK INPUT
% ------------------------------------------------------------------------------------------
sz = size(data);
N = sz(3);
frameSize = sz(1:2);
nPixPerFrame = frameSize(1)*frameSize(2);
overNotOver = reshape([true,false], [1 1 2]);
dataClass = class(data);
if nargin<2
   %    frameInfo = [];
   frameNum = 1:N;
else
   frameNum = cat(1,frameInfo.frame);
end

% ------------------------------------------------------------------------------------------
% INPUT PARAMETERS (TODO) ---> LOOK INTO UREAL and GENMAT
% ------------------------------------------------------------------------------------------
upperThresholdCoefficient = 1.0;	% [over under] As a multiple of the standard-deviation approximation in stat.std
lowerThresholdCoefficient = 1.0;
pctActiveUpperLim= 4.5; %  .01 = 10K pixels (15-30 cells?)
pctActiveLowerLim = .05; % previous values: 500, 250
thresholdStep = 1;
minRoiPixArea = 50; %previously 50
maxRoiPixArea = 300; %previously 350, then 650, then 250
maxRoiEccentricity = .93;%previously .92
maxPerimOverSqArea = 6; %  circle = 3.5449, square = 4 % Previousvalues: [6.5  ]
minPerimOverSqArea = 3.0; % previously 3.5 PERIMETER / SQRT(AREA)
numSampleFrames = 100;
extremeValuePercentTrim = 10; % for builtin function trimmean()
maxIterations = 128;
option.useGpu = false; %TODO - %  option = checkFluoProOptions

% ------------------------------------------------------------------------------------------
% GET SAMPLE VIDEO STATISTICS AND DEFINE MIN/MAX ROI AREA
% ------------------------------------------------------------------------------------------
stat = getDataSampleStatistics(data, numSampleFrames, extremeValuePercentTrim);
meanPixelIntensity = mean2(stat.mean);

% ------------------------------------------------------------------------------------------
% DEFINE FUNCTIONS TO CALCULATE DYNAMIC SIGNAL THRESHOLD ARRAY
% ------------------------------------------------------------------------------------------
calculatePixelUpperThreshold = @ (coeff) cast(stat.mean + coeff.*stat.upperstd, dataClass);
calculatePixelLowerThreshold = @ (coeff) cast(stat.mean - coeff.*stat.lowerstd, dataClass);
bipolarPixelThreshold = @(upperCoeff,lowerCoeff) cat(3,...
   calculatePixelUpperThreshold(upperCoeff),...
   calculatePixelLowerThreshold(lowerCoeff));
bipolarAdaptiveThreshold = bipolarPixelThreshold( upperThresholdCoefficient, lowerThresholdCoefficient);

% ------------------------------------------------------------------------------------------
% DEFINE FUNCTIONS THAT CONDENSE ACTIVE PIXELS INTO ACTIVE REGIONS
% ------------------------------------------------------------------------------------------
morphOverUpper = @(bw) bwmorph(bwmorph(bwmorph( bw, 'open'), 'shrink'), 'majority');
morphUnderLower = @(bw) bwmorph(bwmorph(bwmorph( bw, 'open'), 'shrink'), 'majority');
percentActiveArea = @(bw) 100*nnz(bw)/nPixPerFrame;

% ------------------------------------------------------------------------------------------
% RUN A FEW FRAMES THROUGH HOTSPOT FINDING FUNCTION TO IMPROVE INITIAL SIGNAL THRESHOLD
% ------------------------------------------------------------------------------------------
rgbImage = zeros([frameSize, 3],'uint8');
h.im = handle(imshow(rgbImage));
h.ax = handle(gca);
h.ax.DrawMode = 'fast';
t=hat;
h.text(1) = handle(text(10,30,sprintf('Assessing TEMPORAL-REGIONAL Signal in Frame #%i (%f secs-per-frame)\n',1, hat-t), 'Color','r'));
h.text(2) = handle(text(10,60,'   (Dynamic Signal Threshold)', 'Color','b'));
for k = fliplr(round(linspace(1,N,min(20,N))))
   [~, bipolarAdaptiveThreshold] = getAdaptiveHotspots(data(:,:,k), bipolarAdaptiveThreshold);
   
   h.text(1).String = sprintf('TUNING ADAPTIVE THRESHOLDER in Frame #%i (%f secs-per-frame)\n',k, hat-t);
   t = hat;
end
%*************** end setup

% ------------------------------------------------------------------------------------------
% GET HOTSPOT-BASED ROIS (WHENEVER SIGNAL INTENSITY EXCEEDS PIXEL-SPECIFIC THRESHOLD)
% ------------------------------------------------------------------------------------------
bwMask = false([frameSize N]);
% thresholdTemporalStability = zeros(N,1);
for k = 1:N
   h.text(1).String = sprintf('Assessing TEMPORAL-REGIONAL Signal in Frame #%i (%f secs-per-frame)\n',k, hat-t);
   t = hat;
   [bwMask(:,:,k), bipolarAdaptiveThreshold] = getAdaptiveHotspots(data(:,:,k), bipolarAdaptiveThreshold);
end
frameROI = cell(N,1);
for kp = 1:N
   % ---------------------------------------------------------------------------------------
   % EVALUATE CONNECTED COMPONENTS FROM BINARY 'BLOBBED' MATRIX
   % ---------------------------------------------------------------------------------------
   bwRP =  regionprops(bwMask(:,:,kp),...
	  'Centroid', 'BoundingBox','Area',...
	  'Eccentricity', 'PixelIdxList','Perimeter');
   % ---------------------------------------------------------------------------------------
   % ENFORCE MORPHOLOGY RESTRICTIONS
   % ---------------------------------------------------------------------------------------
   bwRP = bwRP([bwRP.Area] >= minRoiPixArea);	%	Enforce MINIMUM SIZE
   bwRP = bwRP([bwRP.Area] <= maxRoiPixArea);	%	Enforce MAXIMUM SIZE
   bwRP = bwRP([bwRP.Eccentricity] <= maxRoiEccentricity); %  Enforce PLUMP SHAPE
   bwRP = bwRP([bwRP.Perimeter]./sqrt([bwRP.Area]) < maxPerimOverSqArea); %  Enforce LOOSELY CIRCULAR/SQUARE SHAPE
   bwRP = bwRP([bwRP.Perimeter]./sqrt([bwRP.Area]) > minPerimOverSqArea); %  Enforce NON-HOLINESS (SELF-FULFILLMENT?)
   if isempty(bwRP)
	  continue
   end
   % ---------------------------------------------------------------------------------------
   % FILL 'REGIONOFINTEREST' CLASS OBJECTS (several per frame)
   % ---------------------------------------------------------------------------------------
   frameROI{kp,1} = RegionOfInterest(bwRP);
   set(frameROI{kp,1},...
	  'Frames',frameNum(kp),...
	  'FrameSize',frameSize);
end
roi = cat(1,frameROI{:});










% ################################################################
% FUNCTION TO MAKE BINARY MASK WITH ADAPTIVE THRESHOLD
% ################################################################
   function [activeXorInactive, bipolarThresh]  = getAdaptiveHotspots(im, bipolarThresh)
	  % INPUTS
	  %		im: Image Frame - [nrow,ncol,1] uint8 or uint16
	  %		pxth: Pixel Threshold - [nrow,ncol,2] logical
	  
	  
	  % -------------------------------------------------------------------------------------
	  % PREVENT RACE CONDITION OR NON-SETTLING THRESHOLD
	  % -------------------------------------------------------------------------------------
	  % 	  persistent depth
	  % 	  if isempty(depth)
	  % 		 depth = 0;
	  % 	  else
	  % 		 depth = depth + 1;
	  % 		 % 		 thresholdStep = 1 + depth;
	  % 	  end
	  % 	  if depth > recursionLim
	  % 		 warning('Recursion limit exceeded')
	  % 		 depth = 0;
	  % 		 bw = false(size(pxth));
	  % 		 pxth = bipolarPixelThreshold(upperThresholdCoefficient,lowerThresholdCoefficient);   % NEW, (reset)
	  % 		 return
	  % 	  end
	  
	  % -------------------------------------------------------------------------------------
	  % USE THRESHOLD MATRIX TO MAKE BINARY IMAGE, THEN APPLY MORPHOLOGICAL OPERATIONS
	  % -------------------------------------------------------------------------------------
	  % 	  im = gpuArray(im);
	  % 	  bw = im > pxth;
	  % 	  bw = gather(bwmorph(bwmorph(bwmorph( bw, 'open'), 'shrink'), 'majority'));%4
	  % 	  pxOverUnder = bsxfun(@and, bsxfun(@gt, im, pxth), overNotOver);
	  
	  % 	  pxOverUnder = bsxfun(@gt, im, pxth);
	  % 	  pxOverUnder(:,:,1) = morphOverUpper(pxOverUnder(:,:,1));
	  % 	  pxOverUnder(:,:,2) = morphUnderLower(pxOverUnder(:,:,2));
	  
	  
	  
	  % -------------------------------------------------------------------------------------
	  % CHECK FOR OVER/UNDER-THRESHOLDING
	  % -------------------------------------------------------------------------------------
	  activityTargetMet = false(2,1);
	  % POSITIVE
	  pxth = bipolarThresh(:,:,1);
	  downCounter = maxIterations;
	  while downCounter > 0
		 pxOver = morphOverUpper((im>pxth) & (im>2*meanPixelIntensity));		 
		 pctActive = percentActiveArea(pxOver);
		 if pctActive > pctActiveUpperLim
			pxth = pxth + thresholdStep;
			fprintf('increased over\n')
		 elseif pctActive < pctActiveLowerLim
			pxth = pxth - thresholdStep;
			fprintf('decreased over\n')
		 else
			activityTargetMet(1) = true;
			break
		 end
		 downCounter = downCounter - 1;
	  end
	  posPctActive = pctActive;
	  bipolarThresh(:,:,1) = pxth;
	  % NEGATIVE
	  pxth = bipolarThresh(:,:,2);
	  downCounter = maxIterations;
	  while downCounter > 0
		 pxUnder = morphUnderLower((im<pxth) & (im>2*meanPixelIntensity));
		 pctActive = percentActiveArea(pxUnder);
		 if pctActive > pctActiveUpperLim
			pxth = pxth - thresholdStep;
			fprintf('decreased under\n')
		 elseif pctActive < pctActiveLowerLim
			pxth = pxth + thresholdStep;
			fprintf('increased under\n')
		 else
			activityTargetMet(2) = true;
			break
		 end
		 downCounter = downCounter - 1;
	  end
	  negPctActive = pctActive;
	  bipolarThresh(:,:,2) = pxth;
	  
	  % CHECK IF TARGET MET (TODO)
	  activeXorInactive = xor(pxOver,pxUnder);
	  h.im.CData = cat(3, uint8(pxOver)*100, im, uint8(pxUnder)*100);
	   h.text(2).String = sprintf('AREA ACTIVE\n\tPositive: %g\n\tNegative: %g',posPctActive,negPctActive);
	  drawnow 
   end
end




















































classdef (CaseInsensitiveProperties = true) RoiGenerator < FluoProFunction
	% RoiGenerator
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
	
	
	
	
	properties
		upperThresholdCoefficient = 1.5;        % [over under] As a multiple of the standard-deviation approximation in obj.stat.std
		lowerThresholdCoefficient = 1.5;
		pctActiveUpperLim= 10;					% previously 4.5 .01 = 10K pixels (15-30 cells?)
		pctActiveLowerLim = .01;				% previous values: .05
		thresholdStep = 1;
		minRoiPixArea = 35;						% previously 50
		maxRoiPixArea = 1000;					% previously 350, then 650, then 250
		maxRoiEccentricity = .93;               % previously .92
		maxPerimOverSqArea = 6;					% circle = 3.5449, square = 4 % Previousvalues: [6.5  ]
		minPerimOverSqArea = 3.0;				% previously 3.5 PERIMETER / SQRT(AREA)
		numSampleFrames = 2500;
		extremeValuePercentTrim = 10;			% for builtin function trimmean()
		maxIterations = 32;
		bufferedSurroundNumFrames = 10;
		showDisplay = false;
	end
	properties (SetAccess = 'protected')
		meanPixelIntensity
		roi
		frameSize
		dataClass
		foregroundMask
		activityMask
		bufferedMaxSurround
		bufferedMinSurround
	end
	
	
	
	
	
	
	
	
	methods
		function obj = RoiGenerator(varargin)
			obj = getSettableProperties(obj);
			obj = parseConstructorInput(obj,varargin(:));
		end
		
		
		
		
		function obj = initialize(obj)
			
			
			% ------------------------------------------------------------------------------------------
			% CHECK INPUT
			% ------------------------------------------------------------------------------------------
			sz = size(obj.data);
			% 			N = sz(3);
			obj.frameSize = sz(1:2);
			% 			nPixPerFrame = frameSize(1)*frameSize(2);
			% 			dataClass = class(data);
			
			% ------------------------------------------------------------------------------------------
			% INPUT PARAMETERS (TODO) ---> LOOK INTO UREAL and GENMAT
			% ------------------------------------------------------------------------------------------
			
			% ------------------------------------------------------------------------------------------
			% GET SAMPLE VIDEO STATISTICS AND DEFINE MIN/MAX ROI AREA
			% ------------------------------------------------------------------------------------------
			obj = getDataSampleStatistics(obj, obj.numSampleFrames, obj.extremeValuePercentTrim);
			obj.meanPixelIntensity = mean2(obj.stat.mean);
			obj.dataClass = class(obj.data);
			
			% GET A FOREGROUND (CELL) MASK
			obj.foregroundMask = imdilate(imclose(abs(...
				double(obj.stat.upperstd)-double(obj.stat.lowerstd))>1,...
				strel('disk',2,8) ),...
				strel('disk',5,8));
			
			% INITIALIZE BUFFERED SURROUND FRAMES
			nbuf = obj.bufferedSurroundNumFrames;
			if isempty(nbuf)
				nbuf = 5;
			end
			obj.bufferedMaxSurround = zeros([obj.frameSize nbuf], obj.dataClass);
			obj.bufferedMinSurround = zeros([obj.frameSize nbuf], obj.dataClass);
		end
		
		function obj = run(obj)
			% run
			
			% ------------------------------------------------------------------------------------------
			% LOCAL VARIABLES
			% ------------------------------------------------------------------------------------------
			N = obj.nFrames;
			fullFrameSize = obj.frameSize;
			nPixPerFrame = prod(fullFrameSize);
			minArea = obj.minRoiPixArea;
			maxArea = obj.maxRoiPixArea;
			maxEccent = obj.maxRoiEccentricity;
			maxEdgeSurfRatio = obj.maxPerimOverSqArea;
			minEdgeSurfRatio = obj.minPerimOverSqArea;
			isShowDisplay = obj.showDisplay;
			if ~isempty(obj.stableFrames)
				useFrame = obj.stableFrames(:);
			else
				useFrame = true(N,1);
			end
			if ~isempty(obj.frameIdx)
				frameNum = obj.frameIdx;
			else
				frameNum = 1:N;
			end
			
			% ------------------------------------------------------------------------------------------
			% DEFINE FUNCTIONS TO CALCULATE DYNAMIC SIGNAL THRESHOLD ARRAY
			% ------------------------------------------------------------------------------------------
			calculatePixelUpperThreshold = @ (coeff) cast(obj.stat.mean + coeff.*obj.stat.upperstd, obj.dataClass);
			calculatePixelLowerThreshold = @ (coeff) cast(obj.stat.mean - coeff.*obj.stat.lowerstd, obj.dataClass);
			bipolarPixelThreshold = @(upperCoeff,lowerCoeff) cat(3,...
				calculatePixelUpperThreshold(upperCoeff),...
				calculatePixelLowerThreshold(lowerCoeff));
			bipolarAdaptiveThreshold = bipolarPixelThreshold( obj.upperThresholdCoefficient, obj.lowerThresholdCoefficient);
			
			% ------------------------------------------------------------------------------------------
			% DEFINE FUNCTIONS THAT CONDENSE ACTIVE PIXELS INTO ACTIVE REGIONS
			% ------------------------------------------------------------------------------------------
			% 			if obj.useGpu
			% 				morphOverUpper = @(bw) gather(bwmorph(bwmorph(bwmorph( gpuArray(bw), 'open'), 'shrink'), 'majority'));
			% 				morphUnderLower = @(bw) gather(bwmorph(bwmorph(bwmorph( gpuArray(bw), 'open'), 'shrink'), 'majority'));
			% 			else
			morphOverUpper = @(bw) bwmorph(bwmorph(bwmorph( bw, 'open'), 'shrink'), 'majority');
			morphUnderLower = @(bw) bwmorph(bwmorph(bwmorph( bw, 'open'), 'shrink'), 'majority');
			% 			end
			percentActiveArea = @(bw) 100*nnz(bw)/nPixPerFrame;
			
			% ------------------------------------------------------------------------------------------
			% RUN A FEW FRAMES THROUGH HOTSPOT FINDING FUNCTION TO IMPROVE INITIAL SIGNAL THRESHOLD
			% ------------------------------------------------------------------------------------------
			if isShowDisplay
				rgbImage = zeros([obj.frameSize, 3],'uint8');
				h.im = handle(imshow(rgbImage));
				h.ax = handle(gca);
				h.ax.DrawMode = 'fast';
				t=hat;
				h.text(1) = handle(text(10,30,sprintf('Assessing TEMPORAL-REGIONAL Signal in Frame #%i (%f secs-per-frame)\n',1, hat-t), 'Color','r'));
				h.text(2) = handle(text(10,60,'   (Dynamic Signal Threshold)', 'Color','b'));
			end
			for k = fliplr(round(linspace(1,N,min(20,N))))
				if obj.useGpu
					F = gpuArray(obj.data(:,:,k));
				else
					F = obj.data(:,:,k);
				end
				[~, bipolarAdaptiveThreshold] = getAdaptiveHotspots(F, bipolarAdaptiveThreshold);
				if isShowDisplay
					h.text(1).String = sprintf('TUNING ADAPTIVE THRESHOLDER in Frame #%i (%f secs-per-frame)\n',k, hat-t);
					t = hat;
				end
			end
			%*************** end setup
			
			% ------------------------------------------------------------------------------------------
			% GET HOTSPOT-BASED ROIS (WHENEVER SIGNAL INTENSITY EXCEEDS PIXEL-SPECIFIC THRESHOLD)
			% ------------------------------------------------------------------------------------------
			% 			bwMask = false([obj.frameSize N]);
			% 			bufMax = obj.bufferedMaxSurround;
			% 			bufMin = obj.bufferedMinSurround;
			% 			maxSurround = logical(getnhood(strel('disk',ceil(sqrt(minArea/pi)/2),8)));
			% 			minSurround = ~logical(getnhood(strel('disk',ceil(sqrt(maxArea/pi)*2),8)));
			
			% thresholdTemporalStability = zeros(N,1);
			if isempty(obj.activityMask) %TODO: Remove?
				for k = 1:N
					if useFrame(k)
						if isShowDisplay
							h.text(1).String = sprintf('Assessing TEMPORAL-REGIONAL Signal in Frame #%i (%f secs-per-frame)\n',k, hat-t);
							t = hat;
						end
						if obj.useGpu
							F = gpuArray(obj.data(:,:,k));
						else
							F = obj.data(:,:,k);
						end
						[hotspotmask, bipolarAdaptiveThreshold] = getAdaptiveHotspots(F, bipolarAdaptiveThreshold);
						% 						localMin = ordfilt2(F, 1, minSurround);
						% 						bwMask(:,:,k) = hotspotmask;
						% 						surroundingMax = ordfilt2(F, 9, maxSurround);
						% 						bufMin = cat(3,localMin, bufMin(:,:,1:end-1));
						% 						bufMax = cat(3,surroundingMax, bufMax(:,:,1:end-1));
						% 						glowmask = any(bufMin > bufMax, 3);
						% 						bwMask(:,:,k) = hotspotmask | glowmask;
						bwMask(:,:,k) = hotspotmask;
					end
				end
				obj.activityMask = bwMask;
			else
				bwMask = obj.activityMask;
			end
			nPix = squeeze(sum(sum(bwMask,1),2));
			frameROI = cell(N,1);
			
			parfor kp = 1:N
				try
					if useFrame(kp,1) && (nPix(kp,1) > minArea)
						% ---------------------------------------------------------------------------------------
						% EVALUATE CONNECTED COMPONENTS FROM BINARY 'BLOBBED' MATRIX
						% ---------------------------------------------------------------------------------------
						bwRP =  regionprops(bwMask(:,:,kp),...
							'Centroid', 'BoundingBox','Area',...
							'Eccentricity', 'PixelIdxList','Perimeter');
						if isempty(bwRP)
							continue
						end
						% ---------------------------------------------------------------------------------------
						% ENFORCE MORPHOLOGY RESTRICTIONS
						% ---------------------------------------------------------------------------------------
						bwRP = bwRP([bwRP.Area] >= minArea);	%	Enforce MINIMUM SIZE
						bwRP = bwRP([bwRP.Area] <= maxArea);	%	Enforce MAXIMUM SIZE
						bwRP = bwRP([bwRP.Eccentricity] <= maxEccent); %  Enforce PLUMP SHAPE
						bwRP = bwRP([bwRP.Perimeter]./sqrt([bwRP.Area]) < maxEdgeSurfRatio); %  Enforce LOOSELY CIRCULAR/SQUARE SHAPE
						bwRP = bwRP([bwRP.Perimeter]./sqrt([bwRP.Area]) > minEdgeSurfRatio); %  Enforce NON-HOLINESS (SELF-FULFILLMENT?)
						if isempty(bwRP)
							continue
						end
						% ---------------------------------------------------------------------------------------
						% FILL 'REGIONOFINTEREST' CLASS OBJECTS (several per frame)
						% ---------------------------------------------------------------------------------------
						frameROI{kp,1} = RegionOfInterest(bwRP);
						set(frameROI{kp,1},...
							'Frames',frameNum(kp),...
							'FrameSize',fullFrameSize);
					end
				catch
					% 					obj.roi = cat(1,frameROI{:});
				end
			end
			obj.roi = cat(1,frameROI{:});
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
				downCounter = obj.maxIterations;
				while downCounter > 0
					pxOver = morphOverUpper((im>pxth) & (im>2*obj.meanPixelIntensity));
					pctActive = percentActiveArea(pxOver);
					if pctActive > obj.pctActiveUpperLim
						pxth = pxth + obj.thresholdStep;
						fprintf('increased over\n')
					elseif pctActive < obj.pctActiveLowerLim
						pxth = pxth - obj.thresholdStep;
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
				downCounter = obj.maxIterations;
				while downCounter > 0
					pxUnder = morphUnderLower((im<pxth) & (im>2*obj.meanPixelIntensity));
					pctActive = percentActiveArea(pxUnder);
					if pctActive > obj.pctActiveUpperLim
						pxth = pxth - obj.thresholdStep;
						fprintf('decreased under\n')
					elseif pctActive < obj.pctActiveLowerLim
						pxth = pxth + obj.thresholdStep;
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
				try
					activeXorInactive = gather(xor( ...
						bsxfun(@and, pxOver, activityTargetMet(1)),...
						bsxfun(@and, pxUnder, activityTargetMet(2))));
					if isShowDisplay
						h.im.CData = gather(cat(3, uint8(pxOver)*100, im, uint8(pxUnder)*100));
						h.text(2).String = sprintf('AREA ACTIVE\n\tPositive: %g\n\tNegative: %g',posPctActive,negPctActive);
						drawnow
					end
				catch
					activeXorInactive = xor( ...
						bsxfun(@and, pxOver, activityTargetMet(1)),...
						bsxfun(@and, pxUnder, activityTargetMet(2)));
				end
			end
		end
		
		function [obj, mergedRoi] = finalize(obj)
			mergedRoi = reduceRegions(obj.roi);
			% 			mergedRoi = reduceSuperRegions(obj.roi);
			% 			obj.roi = mergedRoi;
		end
		
		
		
		
		
		
		
		
	end
	
	
	
	
	
end








% scaleTo8 = @(X) uint8( double(X-min(X(:))) ./ (double(range(X(:)))/255));
% inRgbChannel = @(X, ch) circshift(cat(3, zeros([size(X,1) size(X,2) 2],'uint8'),scaleTo8(X)), ch, 3);





































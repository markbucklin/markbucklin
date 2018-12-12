classdef DiffDemonsMotionCorrector < FluoProFunction
   % Implemented by Mark Bucklin 6/12/2014
   %
   
   
   properties
	  getDeformationStats = false
	  accumulatedFieldSmoothing = 5
	  pyramidLevels = 4
	  minIterations = [20 12 8 6] % previously [30 20 10 5]
	  numIterations = [30 20 10 6] % previously [30 20 10 5]
	  correlationMinTolerance = .75
	  expectedMaxMotion = 25
	  numSeedingReferenceFrames = 100
	  firstIdx = 1
   end
   properties (SetAccess = protected)
	  uxyMean
	  fixedRunningMean
	  motionMagnitude
	  motionDirection
	  corrWithMean
	  statsUx
	  statsUy
	  inputRange
	  frameCorr
	  winSampledCorr
	  seedingReferenceFrames
   end
   properties (Transient)
   end
   
   
   
   
   
   
   methods
	  function obj = DiffDemonsMotionCorrector(varargin)
		 obj = getSettableProperties(obj);
		 obj = parseConstructorInput(obj,varargin(:));
		 obj.canUseGpu = true;
		 obj.canUsePct = false;
	  end
	  function obj = initialize(obj)
		 % Check-It: Check the input to this file, which should be passed using GETDATASAMPLE
		 [obj, sampleData] = getDataSample(obj,obj.data);
		 obj.preSample = sampleData;
		 
		 % ------------------------------------------------------------------------------------------
		 % DEFINE DEFAULT FUNCTION PARAMETERS
		 % ------------------------------------------------------------------------------------------
		 % For IMREGDEMONS
		 obj.default.getDeformationStats = true;
		 obj.default.accumulatedFieldSmoothing = 5;
		 obj.default.pyramidLevels = 3;
		 obj.default.numIterations = [25 15 10] ;
		 % FOR STABILITY
		 obj.default.correlationMinTolerance = .5;
		 obj.default.numSeedingReferenceFrames = max(100, floor(obj.nFrames/100));
		 obj.default.firstIdx = 1;
		 obj = checkOptions(obj);
		 
		 % ------------------------------------------------------------------------------------------
		 % CONSTANTS & TRANSFORMATION FUNCTION HANDLES
		 % ------------------------------------------------------------------------------------------
		 % m = 10;
		 N = obj.nFrames;
		 if obj.getDeformationStats
			ustruct = @() struct('max',zeros(N,1),'median',zeros(N,1),'range',zeros(N,1)); %
			obj.statsUx = ustruct();
			obj.statsUy = ustruct();
		 end
		 obj.useGpu = true;
		 obj.inputRange = double([min(sampleData(:)) max(sampleData(:))]);
		 obj.uxyMean = zeros(N,2);
		 obj.corrWithMean = zeros(N,1);
		 
		 % 			obj = getSaturatedRange(obj, [2 99.995]);
		 % 			obj.inputRange = double(obj.saturatedRange);
		 % ------------------------------------------------------------------------------------------
		 % GET SEEDING REFERENCE FRAMES FROM PEAKS IN ACTIVITY
		 % ------------------------------------------------------------------------------------------
		 obj = findWinSampledCorr(obj, obj.data(:,:,obj.firstIdx));
		 meanCorr = mean(obj.winSampledCorr,2);
		 % 			colmaxsum = squeeze(sum(max(obj.data,[],1),2));
		 peakingFrames = pnormalize(squeeze(sum(any(bsxfun(@ge, obj.data,...
			cast(.99*max(obj.data,[],3),'like',obj.data)),1),2)));
		 peakingFrames(meanCorr < median(meanCorr(:))) = NaN;
		 [~,locs] = findpeaks(peakingFrames, 'MinPeakDistance',floor(obj.nFrames/obj.numSeedingReferenceFrames/2));
		 obj.seedingReferenceFrames = locs(:);
		 if isempty(obj.seedingReferenceFrames)
			 obj.seedingReferenceFrames = 1;
		 end
	  end
	  function obj = run(obj)
		 N = obj.nFrames;
		 % 			intScaleCoeff = obj.inputRange(2) - obj.inputRange(1);
		 % 			dRange = double(obj.inputRange);
		 intScaleCoeff = obj.inputRange(2);
		 dClass = class(obj.data);
		 % 			toLogDomain = @(X) log1p(double(gpuArray(X))./double(intScaleCoeff));
		 % 			fromLogDomain = @(X) gather(cast(expm1(X).*double(intScaleCoeff), dClass));
		 
		 % ------------------------------------------------------------------------------------------
		 % INITIALIZATION
		 % ------------------------------------------------------------------------------------------
		 % 			[~,stableIdx] = min(filter(ones(40,1),1,abs(diff(obj.frameCorr(2:end)))));
		 % 			firstIdx = obj.seedingReferenceFrames(end);
		 % 			firstIdx = 1;
		 if obj.useGpu
			fixedFrame = log1p(double(gpuArray(...
			   mean(obj.data(:,:,obj.seedingReferenceFrames), 3)...
			   ))./double(intScaleCoeff));
			% 				obj.data(:,:,obj.firstIdx)...
			% 				mean(obj.data(:,:,obj.frameCorr>median(obj.frameCorr)),3)
			% 				fixedFrame = log1p(mat2gray( gpuArray(obj.data(:,:,1)), dRange));
			% 				Ux = gpuArray.zeros(size(fixedFrame));
			% 				Uy = gpuArray.zeros(size(fixedFrame));
			Crm = gpuArray.nan(N,1);
		 else
			fixedFrame = log1p(double(...
			   mean(obj.data(:,:,obj.seedingReferenceFrames), 3)...
			   )./double(intScaleCoeff));
			% 				mean(obj.data(:,:,obj.frameCorr>median(obj.frameCorr)),3)...
			% 				fixedFrame = log1p(mat2gray( obj.data(:,:,1), dRange));
			% 				Ux = zeros(size(fixedFrame));
			% 				Uy = zeros(size(fixedFrame));
			Crm = NaN(N,1);
		 end
		 nf=0;
		 sizeFixed = size(fixedFrame);
		 xIntrinsicFixed = 1:sizeFixed(2);
		 yIntrinsicFixed = 1:sizeFixed(1);
		 [xIntrinsicFixed,yIntrinsicFixed] = meshgrid(xIntrinsicFixed,yIntrinsicFixed);
		 % CONSTRUCT A SMOOTHED EDGE MASK TO BLUR EDGES OF SHIFTED IMAGE FRAMES
		 edgeFill = imfilter(fixedFrame, fspecial('gaussian',3*obj.expectedMaxMotion+1, obj.expectedMaxMotion),'symmetric');
		 fillDepth = 2*obj.expectedMaxMotion;
		 edgeMask = xIntrinsicFixed <= fillDepth ...
			| yIntrinsicFixed <= fillDepth;
		 edgeMask = edgeMask | rot90(edgeMask,2);
		 xTaper = max(double(~edgeMask),bsxfun(@min, 1,xIntrinsicFixed./fillDepth.*sin(double(xIntrinsicFixed)./fillDepth)));
		 xTaper(xIntrinsicFixed > fillDepth) = 1;
		 xTaper = min(xTaper,fliplr(xTaper));
		 yTaper = max(double(~edgeMask),bsxfun(@min, 1,yIntrinsicFixed./fillDepth.*sin(double(yIntrinsicFixed)./fillDepth)));
		 yTaper(yIntrinsicFixed > fillDepth) = 1;
		 yTaper = min(yTaper,flipud(yTaper));
		 taperMask = xTaper .* yTaper;
		 if obj.useGpu
			taperMask = gpuArray(taperMask);
			edgeFill = gpuArray(edgeFill);
			xIntrinsicFixed = gpuArray(xIntrinsicFixed);
			yIntrinsicFixed = gpuArray(yIntrinsicFixed);
		 end
		 % 			fixedFrame = fixedFrame .* taperMask;
		 obj.fixedRunningMean = fixedFrame;
		 % ------------------------------------------------------------------------------------------
		 % RUN ON SEED FRAMES
		 % ------------------------------------------------------------------------------------------
		 obj = setStatus(obj,0, 'Correcting motion via Diffeomorphic-Demons algorithm: seeding reference frames');
		 for kRef = 1:numel(obj.seedingReferenceFrames)
			obj = setStatus(obj,kRef/N);
			registerFrame(obj.seedingReferenceFrames(kRef))
		 end
		 % ------------------------------------------------------------------------------------------
		 % RUN ON ALL FRAMES
		 % ------------------------------------------------------------------------------------------
		 obj = setStatus(obj,0, 'Correcting motion via Diffeomorphic-Demons algorithm: correcting all frames');
		 for kFrame=1:size(obj.data,3)
			registerFrame(kFrame)
			
			obj = setStatus(obj,kFrame/N);
		 end
		 try
			% GATHER MOTION CORRECTION INFO
			if obj.useGpu
			   obj.corrWithMean = gather(Crm);
			   obj.fixedRunningMean = gather(fixedFrame);
			else
			   obj.fixedRunningMean = fixedFrame;
			   obj.corrWithMean = Crm;
			end
			obj = setStatus(obj,inf);
			
			
			% TODO: ADD A LOCAL FINALIZE FUNCTION
			% 			obj.stableFrames = obj.corrWithMean > median(obj.corrWithMean);
			% 			motion = abs(circshift(ur,1) - circshift(ur,-1))./2 + abs(circshift(ur,1)-ur)./2 + abs(circshift(ur,-1)-ur)./2;
			obj = finalize(obj);
		 catch me
			disp(me.message)
		 end
		 % ################################################################
		 %  SUBFUNCTIONS
		 % ################################################################
		 function registerFrame(k)
			% LOAD NEW MOVING FRAME AND APPLY LAST CORRECTION
			if obj.useGpu
			   movingFrame = log1p(double(gpuArray( obj.data(:,:,k) ))./double(intScaleCoeff));
			   % 					movingFrame = log1p(mat2gray( gpuArray(obj.data(:,:,k)), dRange));
			else
			   movingFrame = log1p(double(obj.data(:,:,k) )./double(intScaleCoeff));
			   % 					movingFrame = log1p(mat2gray( obj.data(:,:,k), dRange));
			end
			% 				preFixedFrame = resampleDisplacedFrame(movingFrame,Ux,Uy);
			% 				movingFrame = movingFrame .* taperMask;
			
			% GET UPDATE - TODO: Try using PageFun here
			if obj.frameCorr(k) > obj.correlationMinTolerance
			   nIter = obj.minIterations;
			elseif obj.frameCorr(k) > obj.correlationMinTolerance -.20
			   nIter = obj.numIterations ;
			else
			   nIter = obj.numIterations * 2;
			end
			runDemons()
			% 				[dxyField, movingFrameAdjusted] = imregdemons(movingFrame, fixedFrame,...
			% 					nIter,...
			% 					'AccumulatedFieldSmoothing',obj.accumulatedFieldSmoothing,...
			% 					'PyramidLevels', obj.pyramidLevels);   % NOTE: made change to imregdemons at line 172
			% 				Ux = dxyField(:,:,1);% TODO: perhaps unneccessary... profile
			% 				Uy = dxyField(:,:,2);
			% 				% APPLY TAPERED BLUR TO EDGE
			% 				movingFrameAdjusted = movingFrameAdjusted .* taperMask + edgeFill .* (1-taperMask);
			% 				% RECORD A RUNNING MEAN OF STABLE FRAMES
			% 				Crm(k) = corr2(movingFrameAdjusted, fixedFrame);
			iterIter = 5;
			while Crm(k) < obj.correlationMinTolerance && iterIter > 0
			   imshow(cat(2,...
				  imfuse(gather(movingFrame), gather(fixedFrame),'Scaling','joint'),...
				  imfuse(gather(movingFrameAdjusted), gather(fixedFrame),'Scaling','joint')))
			   title(sprintf('UNSTABLE Frame %i: Correlation with Mean is %f (attempting more iterations)',k,gather(Crm(k))))
			   drawnow
			   nIter = nIter*2;
			   movingFrame = movingFrameAdjusted;
			   runDemons();
			   imshow(cat(2,...
				  imfuse(gather(movingFrame), gather(fixedFrame),'Scaling','joint'),...
				  imfuse(gather(movingFrameAdjusted), gather(fixedFrame),'Scaling','joint')))
			   title(sprintf('UNSTABLE Frame %i: Correlation with Mean is %f (result of double iterations)',k,gather(Crm(k))))
			   drawnow
			   iterIter = iterIter - 1;
			end
			if Crm(k) > obj.correlationMinTolerance
			   nt = nf / (nf + 1);
			   na = 1/(nf + 1);
			   fixedFrame = fixedFrame*nt + movingFrameAdjusted*na;
			   nf = nf + 1;
			   if any(obj.sampleFrameNumbers == k)
				  imshow(cat(2,...
					 imfuse(gather(movingFrame), gather(fixedFrame),'Scaling','joint'),...
					 imfuse(gather(movingFrameAdjusted), gather(fixedFrame),'Scaling','joint')))
				  title(sprintf('SAMPLE Frame %i: Correlation with Mean is %f',k,gather(Crm(k))))
				  drawnow
			   end
			end
			% EXTRACT REGISTERED FRAME AND MEAN-DISPLACEMENT
			if obj.useGpu
			   obj.data(:,:,k) = gather(cast(expm1( movingFrameAdjusted ).*double(intScaleCoeff), dClass));
			else
			   obj.data(:,:,k) = cast(expm1( movingFrameAdjusted ).*double(intScaleCoeff), dClass);
			end
			ux = gather(mean2(Ux));
			uy = gather(mean2(Uy));
			mag = hypot(ux,uy);
			obj.uxyMean(k,:) = [ux,uy]; % [dx dy]
			obj.motionMagnitude(k) = mag;
			obj.motionDirection(k) = atan2d(uy,ux);
			obj.stableFrames(k) = mag < 1;
% 			obj.stableFrames(k)
			if obj.getDeformationStats
			   fillUstats(Ux,Uy,k)
			end
			obj.frameProcessed(k) = true;
			function runDemons()
			   [dxyField, movingFrameAdjusted] = imregdemons(movingFrame, fixedFrame,...
				  nIter,...
				  'AccumulatedFieldSmoothing',obj.accumulatedFieldSmoothing,...
				  'PyramidLevels', obj.pyramidLevels);   % NOTE: made change to imregdemons at line 172
			   Ux = dxyField(:,:,1);% TODO: perhaps unneccessary... profile
			   Uy = dxyField(:,:,2);
			   % APPLY TAPERED BLUR TO EDGE
			   movingFrameAdjusted = movingFrameAdjusted .* taperMask + edgeFill .* (1-taperMask);
			   % RECORD A RUNNING MEAN OF STABLE FRAMES
			   Crm(k) = corr2(movingFrameAdjusted, fixedFrame);
			end
		 end
		 function smoothedOutputImage = resampleDisplacedFrame(moving,Da_x,Da_y)
			% From builtin function gpuArray\imregdemons resampleMovingWithEdgeSmoothing()
			% sizeFixed = size(Da_x);
			% xIntrinsicFixed = 1:sizeFixed(2);
			% yIntrinsicFixed = 1:sizeFixed(1);
			% [xIntrinsicFixed,yIntrinsicFixed] = meshgrid(xIntrinsicFixed,yIntrinsicFixed);
			
			Uintrinsic = xIntrinsicFixed + Da_x;
			Vintrinsic = yIntrinsicFixed + Da_y;
			smoothedOutputImage = interp2(padarray(moving,[1 1]),Uintrinsic+1,Vintrinsic+1,'linear',0);
			
		 end
		 function fillUstats(ux,uy,n)
			fn = fields(obj.statsUx);
			for fk=1:numel(fn)
			   ff = fn{fk};
			   fcn = str2func(ff);
			   obj.statsUx.(ff)(n) = gather(fcn(ux(:)));
			   obj.statsUy.(ff)(n) = gather(fcn(uy(:)));
			end
			
		 end
	  end
	  function obj = findCorrelationWithFrame(obj,frame)
		 N = obj.nFrames;
		 M = size(frame,3);
		 fixedFrame = gpuArray(frame);
		 if M>1
			C = zeros(N,M,'gpuArray');
			for kn = 1:N
			   movingFrame = gpuArray(obj.data(:,:,kn));
			   parfor km = 1:M
				  C(kn,km) = corr2(fixedFrame(:,:,km), movingFrame);
			   end
			end
		 else
			batchsize = 250;
			b = ceil(N/batchsize);
			C = nan(batchsize,b,'gpuArray');%TODO: check useGpu and usePct
			for kb = 1:b
			   idx = batchsize*(kb-1) + (1:batchsize);
			   idx = idx(idx<=N);
			   movingStack = gpuArray(obj.data(:,:,idx));
			   fprintf('batch %i\n',kb)
			   parfor km = 1:numel(idx)
				  C(km,kb) = corr2(fixedFrame,movingStack(:,:,km));
			   end
			end
		 end
		 obj.frameCorr = gather(C(:));
		 obj.frameCorr = obj.frameCorr(~isnan(obj.frameCorr));
	  end
	  function obj = findWinSampledCorr(obj, frame, nWin)
		 if nargin < 3
			nWin = 25;
		 end
		 subsCenteredOn = @(csub,n) (floor(csub-n/2+1):floor(csub+n/2))';
		 [nRows,nCols] = size(frame);
		 N = obj.nFrames;
		 winSize = 2*floor(min(nRows,nCols)/nWin)+1;
		 rowSubCenters = randi([ceil(nRows/5) floor(4*nRows/5)],nWin,1);
		 colSubCenters = randi([ceil(nCols/5) floor(4*nCols/5)],nWin,1);
		 for k=nWin:-1:1
			rowSubs(:,k) = subsCenteredOn(rowSubCenters(k),winSize);
			colSubs(:,k) = subsCenteredOn(colSubCenters(k),winSize);
			fixedFrame(:,:,1,k) = frame(rowSubs(:,k),colSubs(:,k));
			movingFrame(:,:,:,k) = obj.data(rowSubs(:,k),colSubs(:,k),:);
		 end
		 C = nan(N,nWin);
		 parfor kFrame=1:N
			for kWin = 1:nWin
			   C(kFrame,kWin) = corr2(fixedFrame(:,:,1,kWin),movingFrame(:,:,kFrame,kWin));
			end
		 end
		 obj.winSampledCorr = C;
		 if isempty(obj.frameCorr)
			obj.frameCorr = median(C,2);
		 end
	  end
   end
   
   
   
   
   
end

















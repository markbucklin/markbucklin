classdef (CaseInsensitiveProperties = true) NonrigidMotionCorrector <  scicadelic.SciCaDelicSystem
	% NonrigidMotionCorrector
	
	
	% USER SETTINGS
	properties (Nontunable)
		RegistrationMethod = 'Demons2D'
		MaxIntraFrameDeformation = 5
		MaxInterFrameTranslation = 5		% Limits pixel velocity
		MaxNumBufferedFrames = 10
	end
	properties (Nontunable)
		AccumulatedFieldSmoothing = 3
		PyramidLevels = 3
		NumIterations = [10 10 10]
		UseLogDomain = true
	end
	
	% STATES
	properties (DiscreteState)
		CurrentFrameIdx
		CurrentNumBufferedFrames
	end
	
	% PRIVATE COPIES
	properties (SetAccess = protected, Hidden)
		pMaxInterFrameTranslation
		pMaxIntraFrameDeformation
	end
	
	% TEMPLATES
	properties (SetAccess = protected, Hidden)
		FixedMin
		FixedMax
		FixedMean
		FixedPrevious
	end
	
	% PRIVATE VARIABLES
	properties (SetAccess = protected, Hidden)
		RegistrationMethodSet = matlab.system.StringSet({'Demons2D', 'imregdemons'})
		RegistrationFcn
		PreviousCorrection
		PyramidFilterFcn
	end
	
	
	
	
	
	% CONSTRUCTOR
	methods
		function obj = NonrigidMotionCorrector(varargin)
			parseConstructorInput(obj,varargin(:));
			setProperties(obj,nargin,varargin{:});
		end
	end
	
	% BASIC INTERNAL SYSTEM METHODS
	methods (Access = protected)
		function setupImpl(obj,data)
			% TRAINING
			if isempty(obj.FrameSize)
				obj.FrameSize = [size(data,1), size(data,2)];
			end
			if isempty(obj.InputDataType)
				if isa(data, 'gpuArray')
					obj.InputDataType = classUnderlying(data);
				else
					obj.InputDataType = class(data);
				end
			end
			if isempty(obj.OutputDataType)
				obj.OutputDataType = obj.InputDataType;
			end
			
				if isempty(obj.InputRange) || isempty(obj.OutputRange)
					tuneLimitScalingFactors(obj, data)
				end
				setPrivateProps(obj)
				% CONSTRUCT FILTERS FOR EACH PYRAMID LEVEL
				numPyr = obj.PyramidLevels;
				for kPyr=1:numPyr
					pyrSize = round(obj.FrameSize .* .5.^(numPyr-kPyr));
					sigma = obj.AccumulatedFieldSmoothing*(.75 + .25*rand);
					obj.PyramidFilterFcn{kPyr} = obj.constructLowPassFilter(pyrSize, sigma);
				end
				obj.RegistrationFcn = @alignNonRigid_Demons;
				% DEFAULTS FOR NON-RIGID IMAGE ALIGNMENT
				obj.Default.AccumulatedFieldSmoothing = 5;
				obj.Default.NumIterations = 5;
				obj.Default.MaxNumBufferedFrames = 200;
				obj.Default.UseLogDomain = true;
				fillDefaults(obj)
				% FOR STABILITY
				
				obj.CurrentNumBufferedFrames = 0;
				obj.CurrentFrameIdx = 0;
				% FIXED FRAMES FOR POTENTIAL TEMPLATES
				addToFixedFrame(obj, data);
				% 			obj.FixedMin = data; obj.FixedMax = data; obj.FixedMean = single(data);
				% 			obj.FixedPrevious = data;
			
			if ~isempty(obj.GPuRetrievedProps)
				pushGpuPropsBack(obj);
			end
			setPrivateProps(obj)
		end
		function [data, info] = stepImpl(obj,data)
			obj.CurrentFrameIdx = obj.CurrentFrameIdx + 1;
			k = obj.CurrentFrameIdx;
			% 			fprintf('\tCorrecting Motion: Frame %i\n',k)
			if k == 1
				info.ux = 0;
				info.uy = 0;
				info.dir = 0;
				info.mag = 0;
				info.stable = true;
			else
				[data, info] = alignNonRigid(obj, data);
			end
			if info.mag < 1
				addToFixedFrame(obj,data);
			end
		end
		function resetImpl(obj)
			obj.PreviousCorrection = [];
			obj.CurrentNumBufferedFrames = 0;
			obj.CurrentFrameIdx = 0;
			setPrivateProps(obj)
			setInitialState(obj)
		end
		function releaseImpl(obj)
			fetchPropsFromGpu(obj)
			% 			obj.RigidWinSize = []; obj.MovingSubs = []; obj.FixedSubs = [];
		end
		function s = saveObjectImpl(obj)
			s = saveObjectImpl@matlab.System(obj);
			if isLocked(obj)
				oMeta = metaclass(obj);
				oProps = oMeta.PropertyList(:);
				for k=1:numel(oProps)
					if strcmp(oProps(k).Name,'ChildSystem')
						continue
					else
						s.(oProps(k).Name) = obj.(oProps(k).Name);
					end
				end
			end
			if ~isempty(obj.ChildSystem)
				for k=1:numel(obj.ChildSystem)
					s.ChildSystem{k} = matlab.System.saveObject(obj.ChildSystem{k});
				end
			end
		end
		function loadObjectImpl(obj,s,wasLocked)
			if wasLocked
				% Load child System objects
				if ~isempty(s.ChildSystem)
					for k=1:numel(s.ChildSystem)
						obj.ChildSystem{k} = matlab.System.loadObject(s.ChildSystem{k});
					end
				end
				oMeta = metaclass(obj);
				oProps = oMeta.PropertyList(:);
				% 		 oProps = oProps(~strcmp({oProps.GetAccess},'private'));
				for k=1:numel(oProps)
					if strcmp(oProps(k).Name,'ChildSystem')
						continue
					else
						s.(oProps(k).Name) = obj.(oProps(k).Name);
					end
				end
			end
			% Call base class method to load public properties
			loadObjectImpl@matlab.System(obj,s,[]);
		end
	end
	
	% RUN-TIME HELPER METHODS
	methods (Access = protected)
		function [data, info] = alignNonRigid(obj, data)
			global VID;% TODO
			if isempty(VID)
				if obj.UseInteractive
					VID = vision.VideoPlayer;
				end
			end
			% CONSTANTS
			datatype = 'single';
			[nRows, nCols] = size(data);
			% CONVERT FIXED (TEMPLATE) & MOVING (UNCORRECTED) FRAMES TO FLOATING POINT
			fixedFull = cast(obj.FixedPrevious, datatype);
			movingFull = cast(data, datatype);
			if obj.UseLogDomain
				s = cast(obj.InputScale,datatype);
				b = cast(obj.InputOffset, datatype);
				fixedFull = log1p( (fixedFull-b)./s);
				movingFull = log1p( (movingFull-b)./s);
			end
			% PREALLOCATE DISPLACEMENT FIELD Uxy
			if obj.UseGpu
				UxyField = gpuArray.zeros([nRows, nCols, 2], datatype);
			else
				UxyField = zeros([nRows, nCols, 2], datatype);
			end
			numPyr = obj.PyramidLevels;
			% FIND DISPLACEMENT FIELD AT MULTIPLE RESOLUTIONS (COARSE -> FINE)
			for pyr=1:numPyr
				scaleFactor = .5.^(numPyr-pyr);
				moving = imresize(movingFull, scaleFactor, 'cubic');
				fixed = imresize(fixedFull, scaleFactor, 'cubic');
				gaussFilt = obj.PyramidFilterFcn{pyr};
				N = obj.NumIterations(pyr);
				UxyPyr = alignNonRigid_Demons(obj, moving, fixed, N, gaussFilt);
				UxyField = UxyField + imresize(UxyPyr, 1/scaleFactor, 'cubic');
				UxyField = applyDeformationLimits(obj, UxyField);
				movingFull = resampleDisplacedFrame(obj, movingFull, UxyField(:,:,1), UxyField(:,:,2));
			end
			% CORRECTED FRAME
			uncorrectedData = data;
			data = resampleDisplacedFrame(obj, data, UxyField(:,:,1), UxyField(:,:,2));
			if obj.UseInteractive
				step(VID, gather(single(cat(2,uncorrectedData,data))-single(repmat(obj.FixedMean,1,2))));
			end
			% FILL INFO STRUCTURE
			defMag = arrayfun(@hypot, UxyField(:,:,1), UxyField(:,:,2)); %sqrt(UxyField(:,:,1).^2 + UxyField(:,:,2).^2);
			defDir = arrayfun(@atan2d, UxyField(:,:,2), UxyField(:,:,1));
			umag = mean(defMag(:));
			udir = mean(defDir(:));
			info.ux = mean2(UxyField(:,:,1));
			info.uy = mean2(UxyField(:,:,2));
			info.dir = udir;
			info.mag = umag;
			info.stable = umag < 1;
		end
		function UxyField = alignNonRigid_Demons(obj,  moving, fixed, N, gaussFilt)
			if nargin < 5
				if ~isempty(obj.GaussianFilterFcn)
					gaussFilt = obj.GaussianFilterFcn;
				else
					gaussFilt = @(F)imgaussfilt(F, 5);
				end
			end
			datatype = 'single';
			[nRows, nCols] = size(moving);
			if N >= 1
				moving = cast(moving, datatype);
				fixed = cast(fixed, datatype);
				trybsx = true;
				% PRECONDITION BY REMOVING AREAS OF HIGH ACTIVITY
				nRefFrames = size(fixed,3);
				if obj.UseGpu
					Ux = gpuArray.zeros([nRows, nCols, nRefFrames], datatype);
					Uy = gpuArray.zeros([nRows, nCols, nRefFrames], datatype);
				else
					Ux = zeros([nRows, nCols, nRefFrames], datatype);
					Uy = zeros([nRows, nCols, nRefFrames], datatype);
				end
				if obj.UseGpu && ~trybsx
					if obj.UsePct && nRefFrames > 1
						parfor k=1:nRefFrames
							[Ux(:,:,k), Uy(:,:,k)] = demons2d( moving, fixed(:,:,k), N, Ux(:,:,k),  Uy(:,:,k));
						end
					else
						for k=1:nRefFrames
							[Ux(:,:,k), Uy(:,:,k)] = demons2d( moving, fixed(:,:,k), N, Ux(:,:,k),  Uy(:,:,k));
						end
					end
				else
					% INLINED VECTORIZED ALGORITHM LOG? moving = log1p(moving./max(moving(:)));
					% fixed = log1p(fixed./max(fixed(:)));
					% 					[FgradX,FgradY] = gradient(fixed); %gputimeit -> .0039
					[FgradX,FgradY] = imgradientxy(fixed,'CentralDifference'); % gputimeit .0036
					xIntrinsicFixed = reshape(1:nCols, 1, nCols);
					yIntrinsicFixed = reshape(1:nRows, nRows, 1);
					movingWarped = repmat(moving, [1 1 nRefFrames]);
					for i = 1:N
						if size(movingWarped,3) > 1
							movingWarped = interpn(movingWarped,...
								cast(bsxfun(@plus, Ux, xIntrinsicFixed), datatype),...
								cast(bsxfun(@plus, Uy, yIntrinsicFixed ), datatype),...
								bsxfun(@plus, gpuArray.ones(sizeFixed,datatype) , cast(gpuArray(shiftdim(0:nRefFrames-1,-1)),datatype)),...
								'linear');
						else
							movingWarped = interp2(movingWarped,...
								cast(bsxfun(@plus, Ux, xIntrinsicFixed), datatype),...
								cast(bsxfun(@plus, Uy, yIntrinsicFixed ), datatype), 'linear',NaN);
						end
						% UPDATE FIELD
						[Ux,Uy] = arrayfun(@demonsUpdateField, fixed, FgradX, FgradY, movingWarped, Ux, Uy);
						% REGULARIZE UPDATE
						% 	parfor k=1:nRefFrames Ux(:,:,k) = gaussFilt(Ux(:,:,k)); Uy(:,:,k) =
						% 	gaussFilt(Uy(:,:,k)); end
						if nRefFrames > 1
							Ux = bsxfun(@minus, 1.01*gaussFilt(mean(Ux,3)), .01*Ux);
							Uy = bsxfun(@minus, 1.01*gaussFilt(mean(Uy,3)), .01*Uy);
						else
							Ux = gaussFilt(Ux);
							Uy = gaussFilt(Uy);
							% 						filtSize = floor(min(nRows,nCols)/256)+1;
							% 							Ux = convn(Ux,
							% 							cast(fspecial('average',filtSize),'like',Ux),'same');
							% 							Uy = convn(Uy,
							% 							cast(fspecial('average',filtSize),'like',Uy),'same');
						end
						% Ux(:,:,k) = convn(Ux, Hreg, 'same'); Uy = convn(Uy, Hreg, 'same'); Ux =
						% medfilt2(Ux,medFiltSize); Ux = gaussFilt(Ux, sigma,...
						% 		'Padding','circular',... 'FilterDomain','frequency');
						% Uy = medfilt2(Uy,medFiltSize); Uy = gaussFilt(Uy, sigma,...
						% 	'Padding','circular',... 'FilterDomain','frequency');
						% 	'FilterSize',filtSize,... Ux = imfilter(Ux, hGaussian,'replicate'); Uy =
						% 	imfilter(Uy, hGaussian,'replicate');
						% imshowpair(gather(movingWarped), gather(moving))
					end
				end
				UxyField = cat(3, mean(Ux, 3), mean(Uy, 3));
			else
				if obj.UseGpu
					UxyField = gpuArray.zeros([nRows, nCols, 2], datatype);
				else
					UxyField = zeros([nRows, nCols, 2], datatype);
				end
			end
		end
		function Uxy = applyDeformationLimits(obj, Uxy)
			% 		  [nRows, nCols, nDim] = size(Uxy);
			% LIMIT PIXEL VELOCITY (INTER-FRAME DEFORMATION DIFFERENCE)
			if ~isempty(obj.PreviousCorrection)
				lastUxy = cast(obj.PreviousCorrection, 'like', Uxy);
			else
				lastUxy = Uxy;
				lastUxy(:) = 0;
			end
			maxInter = cast(obj.pMaxInterFrameTranslation,'like',Uxy);
			maxIntra = cast(obj.pMaxIntraFrameDeformation, 'like', Uxy);
			Uxyt = Uxy - lastUxy;
			UxytOverLimitMask = abs(Uxyt) > maxInter;
			Uxy(UxytOverLimitMask) = lastUxy(UxytOverLimitMask);
			
			% LIMIT EXPANSION & COMPRESSION (INTRA-FRAME PIXEL-TO-PIXEL DEFORMATION DIFFERENCE)
			colMax = max(Uxy,[], 1);
			rowMax = max(Uxy,[], 2);
			colMin = min(Uxy,[], 1);
			rowMin = min(Uxy,[], 2);
			hvrOverLimit = max(abs(bsxfun( @minus, colMax, rowMin)), abs(bsxfun( @minus, rowMax, colMin))) > maxIntra;
			if any(hvrOverLimit(:))
				Uxy(hvrOverLimit) = 0;
			end
			obj.PreviousCorrection = Uxy;
		end
		function data = resampleDisplacedFrame(obj, data,Ux,Uy)
			global VID2;
			if obj.UseInteractive
				if isempty(VID2)
					VID2 = vision.VideoPlayer;
				end
				VID2.step(gather(sqrt(Ux.^2 + Uy.^2)));
			end
			datatype = 'single';
			[nRows, nCols] = size(Ux);
			xIntrinsicFixed = reshape(1:nCols, 1, nCols);
			yIntrinsicFixed = reshape(1:nRows, nRows, 1);
			fpData = interp2(cast(data,datatype),...
				cast(bsxfun(@plus, Ux, xIntrinsicFixed), datatype),...
				cast(bsxfun(@plus, Uy, yIntrinsicFixed ), datatype), 'linear',NaN);
			% REPLACE MISSING PIXELS ALONG EDGE
			dMask = isnan(fpData);
			fpData(dMask) = obj.FixedPrevious(dMask);
			data = cast(fpData,'like', data);
		end
		function addToFixedFrame(obj,fixedFrame)
			% FIXED MEAN
			nf = min(obj.CurrentNumBufferedFrames, obj.MaxNumBufferedFrames);
			nt = nf / (nf + 1);
			na = 1/(nf + 1);
			obj.FixedMean = obj.FixedMean*nt + single(fixedFrame)*na;
			nf = nf + 1;
			% FIXED MAX & MIN
			obj.FixedMax = max(obj.FixedMax, fixedFrame);
			obj.FixedMin = min(obj.FixedMin, fixedFrame);
			obj.FixedPrevious = fixedFrame;
			obj.CurrentNumBufferedFrames = nf;
		end
	end

	% TUNING
	methods (Hidden)		
		function tuneInteractive(obj)
		end
		function tuneAutomated(obj)
		end
	end
	
	% INITIALIZATION HELPER METHODS
	methods (Access = protected, Hidden)
		function trainInterpolator(obj,fixedFrame)
			if obj.UseGpu %&& ~isa(data, 'gpuArray')
				transferIn = @(x)single(gpuArray(x));
			else
				transferIn = @(x) single(x);
			end
			sizeFixed = size(fixedFrame);
			Xfix = 1:sizeFixed(2);
			Yfix = 1:sizeFixed(1);
			[Xfix,Yfix] = meshgrid(Xfix,Yfix);
			obj.XIntrinsicFixed = transferIn(Xfix);
			obj.YIntrinsicFixed = transferIn(Yfix);
		end		
		function setPrivateProps(obj)
			oMeta = metaclass(obj);
			oProps = oMeta.PropertyList(:);
			for k=1:numel(oProps)
				prop = oProps(k);
				if prop.Name(1) == 'p'
					pname = prop.Name(2:end);
					try
						pval = obj.(pname);
						obj.(prop.Name) = pval;
					catch me
						getReport(me)
					end
				end
			end
		end
		function fetchPropsFromGpu(obj)
			oMeta = metaclass(obj);
			oProps = oMeta.PropertyList(:);
			propSettable = ~[oProps.Dependent] & ~[oProps.Constant];
			for k=1:length(propSettable)
				if propSettable(k)
					pn = oProps(k).Name;
					try
						if isa(obj.(pn), 'gpuArray') && existsOnGPU(obj.(pn))
							obj.(pn) = gather(obj.(pn));
							obj.GpuRetrievedProps.(pn) = obj.(pn);
						end
					catch me
						getReport(me)
					end
				end
			end
		end
		function pushGpuPropsBack(obj)
			fn = fields(obj.GpuRetrievedProps);
			for kf = 1:numel(fn)
				pn = fn{kf};
				if isprop(obj, pn)
					if obj.UseGpu
						obj.(pn) = gpuArray(obj.GpuRetrievedProps.(pn));
					else
						obj.(pn) = obj.GpuRetrievedProps.(pn);
					end
				end
			end
		end
	end
	
	
	
	
	
end


% SUB-FUNCTIONS
function [Ux,Uy] = demons2d(moving, fixed, N, Ux, Uy)
% 			gaussFilt = obj.GaussianFilterFcn;
% Cache plaid representation of fixed image grid.
sizeFixed = size(fixed);
% xIntrinsicFixed = gpuArray(1:sizeFixed(2)); yIntrinsicFixed = gpuArray(1:sizeFixed(1));
% [xIntrinsicFixed,yIntrinsicFixed] = meshgrid(xIntrinsicFixed,yIntrinsicFixed); Initialize Gaussian
% filtering kernel r = ceil(3*sigma); d = 2*r+1; hGaussian = gpuArray(fspecial('gaussian',[d
% d],sigma)); CALCULATE COEFFICIENTS
% 				hSize = r;
% 			H = fspecial('gaussian', hSize, sigma); [~, hcol, hrow] = isfilterseparable(H); hCenter
% 			= floor((size(H)+1)/2); hPad = hSize - hCenter;
% Initialize gradient of F for passive force Thirion Demons
filtSize = [7 7];
% moving = log1p(moving./max(moving(:))); fixed = log1p(fixed./max(fixed(:)));
[FgradX,FgradY] = imgradientxy(fixed,'CentralDifference');
% FgradMagSquared = FgradX.^2+FgradY.^2;
xIntrinsicFixed = reshape(1:sizeFixed(2), 1, sizeFixed(2));
yIntrinsicFixed = reshape(1:sizeFixed(1), sizeFixed(1), 1);
% filtSize = 2.^nextpow2(sigma*2+1);
for i = 1:N
	movingWarped = interp2(moving,...
		bsxfun(@plus, Ux, xIntrinsicFixed),...
		bsxfun(@plus, Uy, yIntrinsicFixed ),...
		'linear',...
		NaN);
	% 		xIntrinsicFixed + Ux,... yIntrinsicFixed + Uy,...
	[Ux,Uy] = arrayfun(@demonsUpdateField, fixed, FgradX, FgradY, movingWarped,Ux,Uy);
	
	% Regularize vector field by gaussian smoothing.
	Ux = convn(Ux, cast(fspecial('average',filtSize),'like',Uy),'same');
	Uy = convn(Uy, cast(fspecial('average',filtSize),'like',Uy),'same');
	% 	Ux = medfilt2(Ux,filtSize);
	% 				Ux = gaussFilt(Ux);
	%, sigma,...
	% 					'Padding','circular',... 'FilterDomain','frequency');
	% 	Uy = medfilt2(Uy,filtSize);
	% 				Uy = gaussFilt(Uy);
	%, sigma,...
	% 					'Padding','circular',... 'FilterDomain','frequency');
	% 		'FilterSize',filtSize,...
	% 	Ux = imfilter(Ux, hGaussian,'replicate'); Uy = imfilter(Uy, hGaussian,'replicate');
	% imshowpair(gather(movingWarped), gather(moving))
end
end

classdef  (CaseInsensitiveProperties = true) MotionCorrector ...
		<  scicadelic.SciCaDelicSystem
	% MotionCorrector
	
	
	
	properties (Nontunable)
		RegistrationType = 'Rigid'
		RigidRegistrationMethod = 'PhaseCorrelation'
		NonRigidRegistrationMethod = 'Demons2D'
		SubPixelPrecision = 10
		MaxIntraFrameDeformation = 15
		MaxInterFrameTranslation = 35		% Limits pixel velocity
		MaxNumBufferedFrames = 200
	end
	properties (Nontunable)
		AccumulatedFieldSmoothing = 5
		PyramidLevels = 3
		NumIterations = [35 15 0]
	end
	properties (DiscreteState)
		CurrentFrameIdx
		CurrentNumBufferedFrames
	end
	properties (SetAccess = protected, Nontunable)
		RigidWinSize		% For rigid registration
		FixedSubs			% For rigid registration
		MovingSubs		% For rigid registration
	end
	properties (SetAccess = protected, Hidden)
		pMaxInterFrameTranslation
		pMaxIntraFrameDeformation
		pSubPixelPrecision
	end
	properties (SetAccess = protected, Hidden)
		XIntrinsicFixed
		YIntrinsicFixed
		FixedMin
		FixedMax
		FixedMean
		TrimmedMean
		RegistrationTypeSet = matlab.system.StringSet({'Rigid','NonRigid'})
		RigidRegistrationMethodSet = matlab.system.StringSet({'QuadXCorr','PhaseCorrelation','BlockMatcher','none'})
		NonRigidRegistrationMethodSet = matlab.system.StringSet({'Demons2D', 'none'})
		RegistrationFcn
		RigidRegistrationFcn
		NonRigidRegistrationFcn
		PreviousCorrection
		FilterObjPhaseCorr
		PyramidFilterFcn
	end
	
	
	
	
	
	% ------------------------------------------------------------------------------------------
	% CONSTRUCTOR
	% ------------------------------------------------------------------------------------------
	methods
		function obj = MotionCorrector(varargin)
			parseConstructorInput(obj,varargin(:));
			% 			obj.UseGpu = true; obj.UsePct = true;
			setProperties(obj,nargin,varargin{:});
		end
	end
	
	% ------------------------------------------------------------------------------------------
	% INITIALIZATION HELPER FUNCTIONS
	% ------------------------------------------------------------------------------------------
	methods
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
		function setupRigidRegistration(obj)
			% 			if obj.UseGpu %&& ~isa(data, 'gpuArray')
			% 				transferIn = @(x)single(gpuArray(x));
			% 			else
			% 				transferIn = @(x) single(x);
			% 			end
			% GET SUBSCRIPTS
			subsCenteredOn = @(csub,n) (floor(csub-n/2+1):floor(csub+n/2))';
			nRows = obj.FrameSize(1);
			nCols = obj.FrameSize(2);
			switch getIndex(obj.RigidRegistrationMethodSet, obj.RigidRegistrationMethod)
				case 1 % QUADXCORR ------------------------------------------------------------
					if isempty(obj.RigidWinSize)
						nomSize = min([min(obj.FrameSize)/4 ; max(obj.FrameSize)/6]);
						obj.RigidWinSize = 2*floor(nomSize/2)+1;
					end
					fixedWinSize = obj.RigidWinSize;
					movingWinSize = fixedWinSize - 2*obj.pMaxInterFrameTranslation;
					rowSubCenterUpper = ceil(nRows/4);
					colSubCenterLeft = ceil(nCols/4);
					rowSubCenterLower = floor(3*nRows/4);
					colSubCenterRight = floor(3*nCols/4);
					row.upper = subsCenteredOn(rowSubCenterUpper,fixedWinSize);
					row.lower = subsCenteredOn(rowSubCenterLower,fixedWinSize);
					col.left = subsCenteredOn(colSubCenterLeft,fixedWinSize);
					col.right = subsCenteredOn(colSubCenterRight,fixedWinSize);
					obj.FixedSubs = cat(3, ...
						[row.upper, col.left],...
						[row.upper, col.right],...
						[row.lower, col.left],...
						[row.lower, col.right]);
					row.upper = subsCenteredOn(rowSubCenterUpper,movingWinSize);
					row.lower = subsCenteredOn(rowSubCenterLower,movingWinSize);
					col.left = subsCenteredOn(colSubCenterLeft,movingWinSize);
					col.right = subsCenteredOn(colSubCenterRight,movingWinSize);
					obj.MovingSubs = cat(3, ...
						[row.upper, col.left],...
						[row.upper, col.right],...
						[row.lower, col.left],...
						[row.lower, col.right]);
					obj.RigidRegistrationFcn = @alignRigid_QuadXCorr;
				case 2 % PHASE-CORRELATION --------------------------------------------------
					% CALCULATE WINDOW SIZE THAT OPTIMIZES FFT
					% 					if isempty(obj.RigidWinSize)
					nomSize = min([min(obj.FrameSize)*2/3 ; max(obj.FrameSize)/2]);
					nomSize = 2^(nextpow2(nomSize));
					obj.RigidWinSize = nomSize/2 + obj.pMaxInterFrameTranslation - 1;%  obj.RigidWinSize = 2*floor(nomSize/2)+1;
					% 					end
					fixedWinSize = obj.RigidWinSize;
					movingWinSize = fixedWinSize - 2*obj.pMaxInterFrameTranslation + 1;
					% SUBSCRIPTS FOR SELECTION OF SUB-WINDOWS FOR ALIGNMENT
					rowSubs = subsCenteredOn(floor(nRows/2), fixedWinSize);
					colSubs =  subsCenteredOn(floor(nCols/2), fixedWinSize);
					if obj.UseGpu
						obj.FixedSubs = gpuArray([rowSubs, colSubs]);
					else
						obj.FixedSubs = [rowSubs, colSubs];
					end
					rowSubs = subsCenteredOn(floor(nRows/2), movingWinSize);
					colSubs =  subsCenteredOn(floor(nCols/2), movingWinSize);
					if obj.UseGpu
						obj.MovingSubs = gpuArray([rowSubs, colSubs]);
					else
						obj.MovingSubs = [rowSubs, colSubs];
					end
					% MAKE FILTER FOR SMOOTHING INTERPOLATED SUBPIXELATION
					sigma = obj.SubPixelPrecision/2;
					imSize = obj.SubPixelPrecision*(obj.SubPixelPrecision/2 - 1)+1;
					obj.constructLowPassFilter(imSize, sigma);
					% 					obj.FilterObjPhaseCorr = vision.ImageFilter; if sepcoeff
					% 						obj.FilterObjPhaseCorr.SeparableCoefficients = true;
					% 						obj.FilterObjPhaseCorr.VerticalCoefficients =
					% 						transferIn(hcol);
					% 						obj.FilterObjPhaseCorr.HorizontalCoefficients =
					% 						transferIn(hrow);
					% 					else
					% 						obj.FilterObjPhaseCorr.Coefficients = transferIn(H);
					% 					end obj.FilterObjPhaseCorr.OutputSize = 'Same as first
					% 					input'; obj.FilterObjPhaseCorr.PaddingMethod = 'Constant';
					% 					obj.FilterObjPhaseCorr.PaddingValue = transferIn(0); %
					% 					obj.FilterObjPhaseCorr.CoefficientsDataType = 'Same word
					% 					length as input'; obj.FilterObjPhaseCorr.ProductDataType =
					% 					'Same as input'; addChildSystem(obj, obj.FilterObjPhaseCorr)
					obj.RigidRegistrationFcn = @alignRigid_PhaseCorrelation;
				case 3 % BlockMatcher
					
			end
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
	end
	
	% ------------------------------------------------------------------------------------------
	% BASIC INTERNAL SYSTEM METHODS
	% ------------------------------------------------------------------------------------------
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
				trainLimitScalingFactors(obj, data)
			end
			obj.TrimmedMean = trimmean(data(:),25);
			trainInterpolator(obj,data)
			setPrivateProps(obj)
			switch obj.RegistrationTypeSet.getIndex(obj.RegistrationType)
				case 1 % 'Rigid'
					setupRigidRegistration(obj);
					obj.RegistrationFcn = @alignRigid;
				case 2 % 'NonRigid'
					numPyr = obj.PyramidLevels;
					for kPyr=1:numPyr
						pyrSize = round(obj.FrameSize .* .5.^(numPyr-kPyr));
						sigma = obj.AccumulatedFieldSmoothing*(.7 + .3*rand);
						obj.PyramidFilterFcn{kPyr} = obj.constructLowPassFilter(pyrSize, sigma);
					end
					obj.NonRigidRegistrationFcn = @alignNonRigid_Demons;
					obj.RegistrationFcn = @alignNonRigid;
			end
			% FOR NON-RIGID IMAGE ALIGNMENT
			obj.Default.AccumulatedFieldSmoothing = 5;
			obj.Default.NumIterations = 5;
			obj.Default.MaxNumBufferedFrames = 200;
			% FOR STABILITY
			
			obj.CurrentNumBufferedFrames = 0;
			obj.CurrentFrameIdx = 0;
			% FOR RIGID ALIGNMENT
			obj.FixedMin = data;
			obj.FixedMax = data;
			obj.FixedMean = single(data);
			fillDefaults(obj)
			setPrivateProps(obj)
		end
		function [data, info] = stepImpl(obj,data)
			obj.CurrentFrameIdx = obj.CurrentFrameIdx + 1;
			k = obj.CurrentFrameIdx;
			fprintf('\tCorrecting Motion: Frame %i\n',k)
			if k == 1
				info.ux = 0;
				info.uy = 0;
				info.dir = 0;
				info.mag = 0;
				info.stable = true;
			else
				[data, info] = obj.RegistrationFcn(obj,data);
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
	
	% ------------------------------------------------------------------------------------------
	% RUN-TIME HELPER FUNCTIONS
	% ------------------------------------------------------------------------------------------
	methods (Access = protected)
		function [data, info] = alignRigid(obj, data)
			% FIND MULTIPLE GUESSES FOR RIGID REGISTRATION UxyVector format is [RowShiftVector ,
			% ColumnShiftVector]
			if ~isempty(obj.RigidRegistrationFcn)
				UxyVector = obj.RigidRegistrationFcn(obj, data);
			else
				UxyVector = [0 0];
			end
			% CHECK VALIDITY OF GUESSES (RELATIVE TO PREVIOUS REG AND SPECIFIED LIMITS) Uxy format
			% is [RowShiftVector , ColumnShiftVector]
			Uxy = applyTranslationLimits(obj, UxyVector);
			data = translateFrame(obj, data, Uxy);
			% FILL INFO STRUCTURE
			uy = Uxy(1);
			ux = Uxy(2);
			umag = hypot(ux,uy);
			udir = atan2d(uy,ux);
			% FILL INFO STRUCTURE
			info.ux = ux;
			info.uy = uy;
			info.dir = udir;
			info.mag = umag;
			info.stable = umag < 1;
		end
		function UxyVector = alignRigid_QuadXCorr(obj, data)
			% FIND MAX CROSS-CORRELATION
			[xcMeanRow, xcMeanCol] = getSubWinDisplacement(data, obj.FixedMean);
			[xcMinRow, xcMinCol] = getSubWinDisplacement(data, obj.FixedMin);
			[xcMaxRow, xcMaxCol] = getSubWinDisplacement(data, obj.FixedMax);
			UxyVector = cat(2,cat(1,xcMeanRow,xcMinRow,xcMaxRow), cat(1,xcMeanCol, xcMinCol, xcMaxCol));
			function [xcRow, xcCol] = getSubWinDisplacement(moving, fixed)
				for k=size(obj.FixedSubs,3):-1:1
					movingSubWin = single(rot90(moving(obj.MovingSubs(:,1,k), obj.MovingSubs(:,2,k)), 2));
					% 			   movingSubWin = single(moving(obj.MovingSubs(:,1,k),
					% 			   obj.MovingSubs(:,2,k)));
					fixedSubWin = single(fixed(obj.FixedSubs(:,1,k), obj.FixedSubs(:,2,k)));
					subCenter = ceil((size(fixedSubWin) - size(movingSubWin) + 1)/2);
					% 			   subCenter = ceil((size(fixedSubWin) + size(movingSubWin) - 1)/2);
					xc = conv2(fixedSubWin, movingSubWin, 'valid');
					% 			   xc = normxcorr2(movingSubWin,fixedSubWin);
					[~, idx] = max(xc(:));
					[maxRow(k), maxCol(k)] = ind2sub(size(xc), idx);
				end
				xcRow = mean(maxRow(max(abs(diff([maxRow(end) ; maxRow(:)])))<obj.pMaxIntraFrameDeformation) - subCenter(1));
				xcCol = mean(maxCol(max(abs(diff([maxCol(end) ; maxCol(:)])))<obj.pMaxIntraFrameDeformation) - subCenter(2));
			end
		end
		function UxyVector = alignRigid_PhaseCorrelation(obj, data)
			% FIND PHASE ALIGNMENT
			subpix = obj.pSubPixelPrecision;
			gaussFilt = obj.GaussianFilterFcn;
			fxsub = obj.FixedSubs;
			mvsub = obj.MovingSubs;
			fixedSize = length(fxsub);
			movingSize = length(mvsub);
			fsSize = fixedSize + movingSize - 1;
			fsValid = fixedSize - movingSize;
			subCenter = ceil(fsSize/2);
			fixedTemplate = {obj.FixedMean, obj.FixedMin, obj.FixedMax};
			K = numel(fixedTemplate);
			if obj.useGpu
				fss = gpuArray.colon(1,fsSize);
				xcMask = gpuArray(bsxfun(@and, abs(subCenter-fss)<fsValid , abs(subCenter-fss')<fsValid ));
				UxyVector = gpuArray.zeros(K,2);
			else
				fss = 1:fsSize;
				xcMask = bsxfun(@and, abs(subCenter-fss)<fsValid , abs(subCenter-fss')<fsValid );
				UxyVector = zeros(K,2);
			end
			fMoving = fft2(single(rot90(data(mvsub(:,1), mvsub(:,2)),2)), fsSize, fsSize);
			% ALIGN TO THE 3 FIXED TEMPLATES: MEAN, MIN, MAX
			if obj.UsePct
				fxs1 = fxsub(:,1);
				fxs2 = fxsub(:,2);
				xcsp = cell(3,1);
				for k=1:3
					fixed = fixedTemplate{k};
					fFixed = fft2(single(fixed(fxs1,fxs2)), fsSize, fsSize);
					xc = ifft2( fFixed .* fMoving, 'symmetric');
					xc(~xcMask) = 0;
					[maxval, idx] = max(xc(:));
					[maxRow, maxCol] = ind2sub(size(xc), idx);
					% SUBPIXEL
					y = (maxRow-2) : (maxRow+2);
					yq = y(1):(1/subpix):y(end);
					x = (maxCol-2) : (maxCol+2);
					xq = x(1):(1/subpix):x(end);
					[X,Y] = meshgrid(x,y);
					[Xq,Yq] = meshgrid(xq,yq);
					xcsp{k} = interp2(X,Y, xc(y,x)./maxval, Xq, Yq, 'linear');
					% 				end for k=1:3
					xcSubPix = gaussFilt(xcsp{k}); % gputimeit -> .0028
					[~, idx] = max(xcSubPix(:));
					maxRow = Yq(idx);
					maxCol = Xq(idx);
					xcRow = maxRow - subCenter;
					xcCol = maxCol - subCenter;
					UxyVector(k,:) = [xcRow, xcCol];
				end
			else
				[xcMeanRow, xcMeanCol] = getSubWinDisplacement(obj.FixedMean);
				[xcMinRow, xcMinCol] = getSubWinDisplacement(obj.FixedMin);
				[xcMaxRow, xcMaxCol] = getSubWinDisplacement(obj.FixedMax);
				UxyVector = cat(2,cat(1,xcMeanRow,xcMinRow,xcMaxRow), cat(1,xcMeanCol, xcMinCol, xcMaxCol));
			end
			function [xcRow, xcCol] = getSubWinDisplacement(fixed)
				fFixed = fft2(single(fixed(fxsub(:,1),fxsub(:,2))), fsSize, fsSize);
				xc = ifft2( fFixed .* fMoving, 'symmetric');
				xc(~xcMask) = 0;
				[maxval, idx] = max(xc(:));
				[maxRow, maxCol] = ind2sub(size(xc), idx);
				% SUBPIXEL
				y = (maxRow-2) : (maxRow+2);
				yq = y(1):(1/subpix):y(end);
				x = (maxCol-2) : (maxCol+2);
				xq = x(1):(1/subpix):x(end);
				[X,Y] = meshgrid(x,y);
				[Xq,Yq] = meshgrid(xq,yq);
				xcSubPix = gaussFilt(interp2(X,Y, xc(y,x)./maxval, Xq, Yq, 'linear')); % gputimeit -> .0028
				[~, idx] = max(xcSubPix(:));
				maxRow = Yq(idx);
				maxCol = Xq(idx);
				xcRow = maxRow - subCenter;
				xcCol = maxCol - subCenter;
			end
		end
		function Uxy = applyTranslationLimits(obj, UxyVector)
			datatype = 'single';
			% CHECK INTER-FRAME SMOOTHNESS
			lastUxy = cast(obj.PreviousCorrection, 'like', UxyVector);
			if isempty(lastUxy)
				lastUxy = UxyVector;
				lastUxy(:) = 0;
			end
			maxInter = cast(obj.pMaxInterFrameTranslation,'like',UxyVector);
			maxIntra = cast(obj.pMaxIntraFrameDeformation, 'like', UxyVector);
			uy = UxyVector(:,1);
			uytValid = abs(uy-lastUxy(1)) < maxInter;
			uy = uy.*single(uytValid);
			ux = UxyVector(:,2);
			uxtValid = abs(ux-lastUxy(2)) < maxInter;
			ux = ux.*single(uxtValid);
			if isa(UxyVector, 'gpuArray')
				Uxy = gpuArray.zeros([1,2],datatype);
			else
				Uxy = zeros([1,2],datatype);
			end
			% CHECK INTRA-FRAME CONSISTENCY BETWEEN MIN/MAX/MEAN REGISTRATION
			if any(uxtValid)
				if any(any(abs(bsxfun(@minus, ux, ux')) > maxIntra))
					[~,idx] = min(abs(ux)); % [~,idx] = min(abs(uy-lastUxy(1)));
					Uxy(2) = ux(idx);
				else
					Uxy(2) = mean(ux(uxtValid));
				end
			else
				Uxy(2) = 0;
			end
			if any(uytValid)
				if any(any(abs(bsxfun(@minus, uy, uy')) > maxIntra))
					[~,idx] = min(abs(uy));
					Uxy(1) = uy(idx);
				else
					Uxy(1) = mean(uy(uytValid));
				end
			else
				Uxy(1) = 0;
			end
			obj.PreviousCorrection = Uxy;
		end
		function data = translateFrame(obj, data, Uxy)
			dataisongpu = isa(data,'gpuArray');
			X = obj.XIntrinsicFixed;
			Y = obj.YIntrinsicFixed;
			nRows = obj.FrameSize(1);
			nCols = obj.FrameSize(2);
			if isempty(X) || isempty(Y)
				if dataisongpu
					[X, Y] = meshgrid(single(gpuArray.colon(1,nCols)), single(gpuArray.colon(1, nRows)));
				else
					[X, Y] = single(meshgrid(1:nCols,1:nRows));
				end
			end
			% INTERPOLATE OVER NEW GRID SHIFTED BY Ux & Uy
			ux = Uxy(2);
			uy = Uxy(1);
			fpData = single(data);
			fpData = interp2(X, Y, fpData, X-ux, Y-uy, 'linear', NaN);
			% REPLACE MISSING PIXELS ALONG EDGE
			dMask = isnan(fpData);
			fpData(dMask) = obj.FixedMean(dMask);
			data = cast(fpData,'like', data);
		end
		function [data, info] = alignNonRigid(obj, data)
			% 			UxyField = feval(obj.NonRigidRegistrationFcn, obj, data);
			datatype = 'single';
			[nRows, nCols] = size(data);
			fixedFull = cast(obj.FixedMean, datatype);
			% 			fixedFull = cat(3,...
			% 				cast(obj.FixedMin, datatype),...
			% 				cast(obj.FixedMean, datatype),...
			% 				cast(obj.FixedMax, datatype));
			movingFull = cast(data, datatype);
			if obj.UseGpu
				UxyField = gpuArray.zeros([nRows, nCols, 2], datatype);
			else
				UxyField = zeros([nRows, nCols, 2], datatype);
			end
			numPyr = obj.PyramidLevels;
			for pyr=1:numPyr
				scaleFactor = .5.^(numPyr-pyr);
				moving = imresize(movingFull, scaleFactor, 'cubic');
				fixed = imresize(cast(fixedFull,datatype), scaleFactor, 'cubic');
				gaussFilt = obj.PyramidFilterFcn{pyr};
				N = obj.NumIterations(pyr);
				UxyPyr = alignNonRigid_Demons(obj, moving, fixed, N, gaussFilt);
				UxyField = UxyField + imresize(UxyPyr, 1/scaleFactor, 'cubic');
				if obj.UseInteractive && N >= 1
					if ~isempty(obj.PreviousCorrection)
						imagesc(reshape(bsxfun(@minus, UxyField, obj.PreviousCorrection), nRows,2*nCols, 1)), colorbar
						title('Non-Rigid Registration: Deformation Fields Ux (left) and Uy (right)')
						drawnow
					end
				end
				UxyField = applyDeformationLimits(obj, UxyField);
				movingFull = resampleDisplacedFrame(obj, moving, UxyField(:,:,1), UxyField(:,:,2));
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
				% PRECONDITION BY REMOVING AREAS OF HIGH ACTIVITY
				dataLim = cast(obj.TrimmedMean,datatype);
				moving = cast(moving, datatype);
				fixed = cast(fixed, datatype);
				dataLim = dataLim + .25*(max(moving(:))-dataLim);
				moving(moving > dataLim) = dataLim;
				% 			instability = min(sqrt(range(obj.PreviousCorrection(:))+1),5); N =
				% 			real(floor(nIter * instability));
				trybsx = true;
				% 			fieldSmoothing = obj.AccumulatedFieldSmoothing; fixedFrame =
				% 			cast(obj.FixedMean, datatype);
				
				fixed(fixed > dataLim) = dataLim;
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
					% INLINED VECTORIZED ALGORITHM
					sizeFixed = size(fixed);
					% 					filtSize = [7 7]; if obj.UseGpu
					% 						Hreg = repmat(gpuArray(fspecial('average',filtSize)),
					% 						[1,1,nRefFrames]);
					% 					else
					% 						Hreg = repmat(fspecial('average',filtSize),
					% 						[1,1,nRefFrames]);
					% 					end
					moving = log1p(moving./max(moving(:)));
					fixed = log1p(fixed./max(fixed(:)));
					[FgradX,FgradY] = gradient(fixed);
					xIntrinsicFixed = reshape(1:sizeFixed(2), 1, sizeFixed(2));
					yIntrinsicFixed = reshape(1:sizeFixed(1), sizeFixed(1), 1);
					movingWarped = repmat(moving, [1 1 nRefFrames]);
					for i = 1:N
						movingWarped = interpn(movingWarped,...
							bsxfun(@plus, Ux, xIntrinsicFixed),...
							bsxfun(@plus, Uy, yIntrinsicFixed ),...
							bsxfun(@plus, gpuArray.ones(sizeFixed,datatype) , cast(gpuArray(shiftdim(0:nRefFrames-1,-1)),datatype)),...
							'linear',...
							NaN);
						% UPDATE FIELD
						[Ux,Uy] = arrayfun(@demonsUpdateField, fixed, FgradX, FgradY, movingWarped, Ux, Uy);
						% REGULARIZE UPDATE
						% 						parfor k=1:nRefFrames
						% 							Ux(:,:,k) = gaussFilt(Ux(:,:,k)); Ux(:,:,k) =
						% 							gaussFilt(Ux(:,:,k));
						% 						end
						Ux = bsxfun(@minus, 1.25*gaussFilt(mean(Ux,3)), .25*Ux);
						Uy = bsxfun(@minus, 1.25*gaussFilt(mean(Uy,3)), .25*Uy);
						% 						Ux(:,:,k) = convn(Ux, Hreg, 'same'); Uy = convn(Uy,
						% 						Hreg, 'same'); Ux = medfilt2(Ux,medFiltSize);
						% 				Ux = gaussFilt(Ux);
						%, sigma,...
						% 					'Padding','circular',... 'FilterDomain','frequency');
						% 						Uy = medfilt2(Uy,medFiltSize);
						% 				Uy = gaussFilt(Uy);
						%, sigma,...
						% 					'Padding','circular',... 'FilterDomain','frequency');
						% 		'FilterSize',filtSize,...
						% 	Ux = imfilter(Ux, hGaussian,'replicate'); Uy = imfilter(Uy,
						% 	hGaussian,'replicate');
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
				lastUxy = zeros(size(Uxy), 'like', Uxy);
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
			% From builtin function gpuArray\imregdemons resampleMovingWithEdgeSmoothing()
			% 		 sizeFixed = size(Ux); xIntrinsicFixed = 1:sizeFixed(2); yIntrinsicFixed =
			% 		 1:sizeFixed(1); [xIntrinsicFixed,yIntrinsicFixed] =
			% 		 meshgrid(xIntrinsicFixed,yIntrinsicFixed);
			Uintrinsic = obj.XIntrinsicFixed + Ux;
			Vintrinsic = obj.YIntrinsicFixed + Uy;
			fpData = padarray( single(data), [1 1]);
			fpData = interp2(fpData,Uintrinsic+1,Vintrinsic+1,'linear',NaN);
			% REPLACE MISSING PIXELS ALONG EDGE
			dMask = isnan(fpData);
			fpData(dMask) = obj.FixedMean(dMask);
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
			obj.CurrentNumBufferedFrames = nf;
		end
	end
	
	
	
end



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
moving = log1p(moving./max(moving(:)));
fixed = log1p(fixed./max(fixed(:)));
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




% 			function [Da_x, Da_y] = computeUpdateFieldAndComposeWithAccumulatedField(fixed,FgradX,
% 			FgradY, FgradMagSquared, movingWarped,Da_x,Da_y)
% 			   %(moved in) Function scoped broadcast variables for use in zeroUpdateThresholding
% 			   IntensityDifferenceThreshold = 0.001; DenominatorThreshold = 1e-9;
%
% 			   FixedMinusMovingWarped = fixed-movingWarped; denominator =  (FgradMagSquared +
% 			   FixedMinusMovingWarped.^2);
%
% 			   % Compute additional displacement field - Thirion directionallyConstFactor =
% 			   FixedMinusMovingWarped ./ denominator; Du_x = directionallyConstFactor .* FgradX;
% 			   Du_y = directionallyConstFactor .* FgradY;
%
%
% 			   if (denominator < DenominatorThreshold) |...
% 					 (abs(FixedMinusMovingWarped) < IntensityDifferenceThreshold) |...
% 					 isnan(FixedMinusMovingWarped) %#ok<OR2>
%
% 				  Du_x = 0; Du_y = 0;
%
% 			   end
%
% 			   % Compute total displacement vector - additive update Da_x = Da_x + Du_x; Da_y = Da_y
% 			   + Du_y;
%
% 			end

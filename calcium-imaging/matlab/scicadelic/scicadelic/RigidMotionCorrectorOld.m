classdef  (CaseInsensitiveProperties = true) RigidMotionCorrectorOld ...
		<  scicadelic.SciCaDelicSystem
	% RigidMotionCorrector
	
	
	
	properties (Nontunable)
		RigidRegistrationMethod = 'PhaseCorrelation'
		SubPixelPrecision = 10
		MaxIntraFrameDeformation = 10
		MaxInterFrameTranslation = 35		% Limits pixel velocity
		MaxNumBufferedFrames = 200
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
		FixedPrevious
		TrimmedMean
		RigidRegistrationMethodSet = matlab.system.StringSet({'QuadXCorr','PhaseCorrelation','BlockMatcher','none'})
		RegistrationFcn
		PreviousCorrection
		FilterObjPhaseCorr
		PeakFilterFcn
		SubWindowFilterFcn
	end
	
	
	
	
	
	% ------------------------------------------------------------------------------------------
	% CONSTRUCTOR
	% ------------------------------------------------------------------------------------------
	methods
		function obj = RigidMotionCorrectorOld(varargin)
			parseConstructorInput(obj,varargin(:));
			setProperties(obj,nargin,varargin{:});
		end
	end
	
	% ------------------------------------------------------------------------------------------
	% INITIALIZATION HELPER FUNCTIONS
	% ------------------------------------------------------------------------------------------
	methods (Access = protected)
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
						subWinSize = min([min(obj.FrameSize)/4 ; max(obj.FrameSize)/6]);
						obj.RigidWinSize = 2*floor(subWinSize/2)+1;
					end
					subWinSize = obj.RigidWinSize;
					movingWinSize = subWinSize - 2*obj.pMaxInterFrameTranslation;
					rowSubCenterUpper = ceil(nRows/4);
					colSubCenterLeft = ceil(nCols/4);
					rowSubCenterLower = floor(3*nRows/4);
					colSubCenterRight = floor(3*nCols/4);
					row.upper = subsCenteredOn(rowSubCenterUpper,subWinSize);
					row.lower = subsCenteredOn(rowSubCenterLower,subWinSize);
					col.left = subsCenteredOn(colSubCenterLeft,subWinSize);
					col.right = subsCenteredOn(colSubCenterRight,subWinSize);
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
					obj.RegistrationFcn = @alignRigid_QuadXCorr;
				case 2 % PHASE-CORRELATION --------------------------------------------------
					% CALCULATE WINDOW SIZE THAT OPTIMIZES FFT
					% 					if isempty(obj.RigidWinSize)
					subWinSize = min([min(obj.FrameSize)*2/3 ; max(obj.FrameSize)/2]);
					subWinSize = 2^(nextpow2(subWinSize));
					if any(subWinSize > [nRows nCols])
						subWinSize = 2^(nextpow2(subWinSize)-1);
					end
					obj.RigidWinSize = subWinSize;					
					% SUBSCRIPTS FOR SELECTION OF SUB-WINDOWS FOR ALIGNMENT
					rowSubs = subsCenteredOn(floor(nRows/2), subWinSize);
					colSubs =  subsCenteredOn(floor(nCols/2), subWinSize);
					if obj.UseGpu
						obj.FixedSubs = gpuArray([rowSubs, colSubs]);
						obj.MovingSubs = gpuArray([rowSubs, colSubs]);
					else
						obj.FixedSubs = [rowSubs, colSubs];
						obj.MovingSubs = [rowSubs, colSubs];
					end
					% MAKE FILTER FOR SMOOTHING SUBWINDOWS BEFORE TAKING FFT
					sigma = 3;
					obj.SubWindowFilterFcn = obj.constructLowPassFilter(subWinSize, sigma);
					% MAKE FILTER FOR SMOOTHING INTERPOLATED SUBPIXELATION
					sigma = obj.SubPixelPrecision/2;
					imSize = obj.SubPixelPrecision*(obj.SubPixelPrecision/2 - 1)+1;
					obj.PeakFilterFcn = obj.constructLowPassFilter(imSize, sigma);
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
					obj.RegistrationFcn = @alignRigid_PhaseCorrelation;
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
				tuneLimitScalingFactors(obj, data)
			end
			obj.TrimmedMean = trimmean(data(:),25);
			trainInterpolator(obj,data)
			setPrivateProps(obj)
			setupRigidRegistration(obj);
				
					
			obj.Default.MaxNumBufferedFrames = 200;
			
			obj.CurrentNumBufferedFrames = 0;
			obj.CurrentFrameIdx = 0;
			% FOR RIGID ALIGNMENT
			obj.FixedMin = data;
			obj.FixedMax = data;
			obj.FixedMean = single(data);
			obj.FixedPrevious = data;
			fillDefaults(obj)
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
				[data, info] = alignRigid(obj,data);
			end
			if info.mag < 5
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
			% 			if ~isempty(obj.RegistrationFcn)
			% 				Uxy = obj.RegistrationFcn(obj, data);
			% 			else
			% 				Uxy = [0 0];
			% 			end
			% CHECK VALIDITY OF GUESSES (RELATIVE TO PREVIOUS REG AND SPECIFIED LIMITS) Uxy format
			% is [RowShiftVector , ColumnShiftVector]
			% 			Uxy = applyTranslationLimits(obj, UxyVector);
			% 			data = translateFrame(obj, data, Uxy);
			[data, Uxy] = alignRigid_PhaseCorrelation(obj, data);
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
		function [data, Uxy] = alignRigid_PhaseCorrelation(obj, data)
			if obj.useGpu
				Uxy = gpuArray.zeros(1,2);
			else
				Uxy = zeros(1,2);
			end
			if isempty(obj.FixedMean)
				addToFixedFrame(obj,data);
				return
			end
			% FIND PHASE ALIGNMENT			
			subpix = obj.pSubPixelPrecision;
			spGaussFilt = obj.PeakFilterFcn;
			subWinGaussFilt = obj.SubWindowFilterFcn;
			fxsub = obj.FixedSubs;
			mvsub = obj.MovingSubs;
			fixedSize = length(fxsub);
			movingSize = length(mvsub);
			fsSize = fixedSize + movingSize;
			fsValid = 2*obj.MaxInterFrameTranslation;
			subCenter = ceil(fsSize/2);
			padDepth = 10;
			padIdx = [1:padDepth , movingSize-padDepth:movingSize];
			if obj.useGpu
				fss = gpuArray.colon(1,fsSize);
				xcMask = gpuArray(bsxfun(@and, abs(subCenter-fss)<fsValid , abs(subCenter-fss')<fsValid ));
				% 				UxyVector = gpuArray.zeros(K,2);
			else
				fss = 1:fsSize;
				xcMask = bsxfun(@and, abs(subCenter-fss)<fsValid , abs(subCenter-fss')<fsValid );
				% 				UxyVector = zeros(K,2);
			end
			% ALIGN WITH PREVIOUS FRAME			
			moving = single(data(mvsub(:,1), mvsub(:,2)));
			fixed = single(obj.FixedPrevious(fxsub(:,1), fxsub(:,2)));
			[uy, ux] = getSubWinDisplacement(moving, fixed);
			UxyPrev = applyTranslationLimits(obj, [uy ux]);
			data = translateFrame(obj, data, UxyPrev);
			% ALIGN WITH MEAN FRAME
			moving = single(data(mvsub(:,1), mvsub(:,2)));
			fixed = single(obj.FixedMean(fxsub(:,1), fxsub(:,2)));
			[uy, ux] = getSubWinDisplacement(moving, fixed);
			UxyMean = applyTranslationLimits(obj, [uy ux]);
			% 			if all(abs(UxyMean) <= abs(UxyPrev))
			Uxy = UxyPrev + UxyMean;
			data = translateFrame(obj, data, UxyMean);
			% 			else
			% 				Uxy = UxyPrev;
			% 			end
			obj.FixedPrevious = data;
			obj.PreviousCorrection = Uxy;
			% SUBFUNCTIONS
			function [xcRow, xcCol] = getSubWinDisplacement(moving, fixed)
				moving = padAndFiltSubwin(moving);
				fMoving = fft2(rot90(moving,2), fsSize, fsSize);
				fixed = padAndFiltSubwin(fixed);
				fFixed = fft2(fixed, fsSize, fsSize);
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
				xcSubPix = spGaussFilt(interp2(X,Y, xc(y,x)./maxval, Xq, Yq, 'linear')); % gputimeit -> .0028
				[~, idx] = max(xcSubPix(:));
				maxRow = Yq(idx);
				maxCol = Xq(idx);
				xcRow = maxRow - subCenter;
				xcCol = maxCol - subCenter;
			end
			function subwin = padAndFiltSubwin(subwin)
				subwin(padIdx, :) = 0;
				subwin(:, padIdx) = 0;
				subwin = subWinGaussFilt(subwin);
			end
		end
		function Uxy = applyTranslationLimits(obj, Uxy)			
			pThrottle = .95;
			% CHECK INTER-FRAME SMOOTHNESS
			lastUxy = cast(obj.PreviousCorrection, 'like', Uxy);
			if isempty(lastUxy)
				lastUxy = Uxy;
				lastUxy(:) = 0;
			end
			maxInter = cast(obj.pMaxInterFrameTranslation,'like',Uxy);
			uy = Uxy(1);
			dUy = uy-lastUxy(1);
			if dUy > maxInter
				uy = maxInter*pThrottle;
			elseif dUy < -maxInter
				uy = -maxInter*pThrottle;
			end						
			ux = Uxy(2);
			dUx = ux - lastUxy(2);
			if dUx > maxInter
				ux = maxInter*pThrottle;
			elseif dUx < -maxInter
				ux = -maxInter*pThrottle;
			end		
			Uxy = [uy ux];
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
	
	
	% TUNING
	methods (Hidden)		
		function tuneInteractive(obj)
		end
		function tuneAutomated(obj)
		end
	end
	
end


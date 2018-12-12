classdef  (CaseInsensitiveProperties = true) RigidMotionCorrectorBackup <  scicadelic.SciCaDelicSystem
	% RigidMotionCorrectorBackup
	
	
	% USER SETTINGS
	properties (Nontunable, PositiveInteger)
		SubPixelPrecision = 10		
		MaxInterFrameTranslation = 50					% Limits pixel velocity
		MaxNumBufferedFrames = 200
		MotionMagDiffStableThreshold = 1			% The maximum magnitude of interframe displacement (in pixels) allowed for inclusion in moving average
	end
	properties (Nontunable, Logical)
		AdjunctFrameInputPort = false
		CorrectedFramesOutputPort = true
		AdjunctFrameOutputPort = false
		CorrectionInfoOutputPort = false
	end
	
	% STATES
	properties (DiscreteState)
		CurrentFrameIdx
		CurrentNumBufferedFrames
	end
	
	% OUTPUTS
	properties (SetAccess = protected)%TODO - move to parent class?
		CorrectedFrames
		AdjunctFrames
		CorrectionInfo		
	end
		
	% PRIVATE COPIES
	properties (SetAccess = protected, Hidden, Nontunable)
		pMaxInterFrameTranslation
		pSubPixelPrecision
		pMaxNumBufferedFrames
		pMotionMagDiffStableThreshold
	end
	
	% TEMPLATES
	properties (SetAccess = protected, Hidden)
		FixedMin
		FixedMax
		FixedMean
		FixedPrevious
	end
	
	% PRIVATE VARIABLES
	properties (SetAccess = protected, Nontunable, Hidden)
		SubWinSize
		SubWinSubscripts
		SubWinAntiEdgeWin
		XcMask
		PeakFilterFcn
		SubWindowFilterFcn
	end
	properties (SetAccess = protected, Hidden)
		XIntrinsicFixed
		YIntrinsicFixed
		LastCorrection = [0 0]
		CorrectionToPrecedingFrame = [0 0]
		CorrectionToMovingAverage = [0 0]
	end
	
	
	
	
	
	% CONSTRUCTOR
	methods
		function obj = RigidMotionCorrectorBackup(varargin)
			parseConstructorInput(obj,varargin(:));
			setProperties(obj,nargin,varargin{:});
		end
		function updateRigid(obj)%TODO: remove
			setupRigidRegistration(obj)
		end
	end
	
	% BASIC INTERNAL SYSTEM METHODS
	methods (Access = protected)
		function setupImpl(obj,data,~)
			
			checkInput(obj, data);
			obj.TuningImageDataSet = [];
			
			trainInterpolator(obj,data)
			setPrivateProps(obj)
			setupRigidRegistration(obj);
			obj.Default.MaxNumBufferedFrames = 200;			
			
			obj.CurrentNumBufferedFrames = 0;
			obj.CurrentFrameIdx = 0;
			obj.LastCorrection = [0 0];
			obj.FixedMin = data(:,:,1);
			obj.FixedMax = data(:,:,1);
			obj.FixedMean = single(data(:,:,1));
			obj.FixedPrevious = data(:,:,1);
			if ~isempty(obj.GpuRetrievedProps)
				pushGpuPropsBack(obj)
			end
			fillDefaults(obj)
			setPrivateProps(obj)
			fprintf('RIGID-MOTION-CORRECTOR SETUP\n')
		end
		function varargout = stepImpl(obj,data, varargin)
			
			% LOCAL VARIABLES
			inputNumFrames = size(data,3);
			N = obj.CurrentFrameIdx;
			
			% BEGIN WITH LAST CORRECTION FOR GENERATING CHANGE (1st Moment)
			lastUxy = onCpu(obj, obj.LastCorrection);
			
			for k=1:inputNumFrames
				
				% INITIALIZE FIRST FRAME WITH ALL ZEROS
				if (N+k) == 1
					Uxy = [0 0];
					info.ux(1) = 0;
					info.uy(1) = 0;
					info.dir(1) = 0;
					info.mag(1) = 0;
					info.dux(1) = 0;
					info.duy(1) = 0;
					info.ddir(1) = 0;
					info.dmag(1) = 0;
					info.stable(1) = true;
					dmag = 0;
				else
					% RUN PROCEDURE: RETURN CORRECTED FRAME AND FRAME-DISPLACEMENT
					fdata = data(:,:,k);
					[fdata, Uxy] = alignFrames(obj, fdata);
					
					% SPLIT X-Y COMPONENTS OF APPLIED CORRECTION AND CALCULATE MAGNITUDE/DIRECTION
					uy = Uxy(1);
					ux = Uxy(2);
					umag = hypot(ux,uy);
					udir = atan2d(uy,ux);
					
					% ALSO SAVE DIFFERENTIAL DISPLACEMENT (1st Moment?)
					duy = uy - lastUxy(1);
					dux = ux - lastUxy(2);
					dmag = hypot(dux, duy);
					ddir = atan2d(duy, dux);
					lastUxy = Uxy;
					
					% FILL INFO STRUCTURE
					info.ux(k,1) = ux;
					info.uy(k,1) = uy;
					info.dir(k,1) = udir;
					info.mag(k,1) = umag;
					info.dux(k,1) = dux;
					info.duy(k,1) = duy;
					info.ddir(k,1) = ddir;
					info.dmag(k,1) = dmag;
					info.stable(k,1) = dmag < obj.pMotionMagDiffStableThreshold;
					data(:,:,k) = fdata;
				end
				
				% ADD FRAMES WITH MINIMAL MOTION TO MOVING AVERAGE
				if dmag < obj.pMotionMagDiffStableThreshold
					addToFixedFrame(obj, data(:,:,k));
				end				
			end
			
			% TRANSLATE ADJUNCT FRAMES IF SPECIFIED
			if obj.AdjunctFrameInputPort ...
					&& (nargin > 2) ...
					&& ~all(Uxy == 0)
				adjunctData = varargin{1};
				for k=1:inputNumFrames
					Uxy = [info.ux(k) info.uy(k)];
					adjunctData(:,:,k) = translateFrame(obj, adjunctData(:,:,k), Uxy);
				end
				obj.AdjunctFrames = adjunctData;
			else
				adjunctData = [];
			end
			
			% UPDATE CURRENT STATES
			obj.CurrentFrameIdx = N + inputNumFrames;
			obj.CorrectedFrames = data;
			obj.CorrectionInfo = info;
			
			% ASSIGN OUTPUT
			availableOutput = {data, adjunctData, info};				
			specifiedOutput = [...
				obj.CorrectedFramesOutputPort,...
				obj.AdjunctFrameOutputPort,...
				obj.CorrectionInfoOutputPort];
			varargout = availableOutput(specifiedOutput);
			
		end
		function numInputs = getNumInputsImpl(obj)
			if obj.AdjunctFrameInputPort
				numInputs = 2;
			else
				numInputs = 1;
			end
		end
		function numOutputs = getNumOutputsImpl(obj)
			numOutputs = nnz([...
				obj.CorrectedFramesOutputPort,...
				obj.AdjunctFrameOutputPort,...
				obj.CorrectionInfoOutputPort]);
		end
		function resetImpl(obj)
			fprintf('RIGID-MOTION-CORRECTOR RESET\n')
			obj.LastCorrection = [0 0];
			% 			obj.CurrentNumBufferedFrames = 0;
			% 			obj.CurrentFrameIdx = 0;
			setPrivateProps(obj)
			setInitialState(obj)
		end
		function releaseImpl(obj)
			fetchPropsFromGpu(obj)
			% 			obj.SubWinSize = []; obj.SubWinSubscripts = []; obj.SubWinSubscripts = [];
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
		function [data, Uxy] = alignFrames(obj, data)
			% Find frame alignment using phase correlation
			
			% ASSIGN ZERO-SHIFT TO FIRST FRAME & RETURN
			if isempty(obj.FixedMean)
				Uxy = zeros(1,2);
				addToFixedFrame(obj,data);
				return
			end
			
			% COPY PROPERTIES TO LOCAL VARIABLES FOR FASTER REUSE
			subpix = obj.pSubPixelPrecision;
			subWinSubs = obj.SubWinSubscripts;
			rowSubs = subWinSubs(:,1);
			colSubs = subWinSubs(:,2);
			subWinSize = length(rowSubs);
			
			% 			freqWinSize = 2*subWinSize;
			freqWinSize = subWinSize;
			subCenter = floor(freqWinSize/2 + 1);
			% 			subCenter = ceil(freqWinSize/2);
			antiEdgeWin = obj.SubWinAntiEdgeWin;
			% 			padDepth = 10;
			% 			padIdx = [1:padDepth , movingSize-padDepth:movingSize];
			xcMask = obj.XcMask;
			
			% ALIGN WITH PREVIOUS-FRAME
			moving = single(data(rowSubs, colSubs));
			fixed = single(obj.FixedPrevious(rowSubs, colSubs));
			[uy, ux] = getSubWinDisplacement(moving, fixed);
			UxyPrev = applyTranslationLimits(obj, [uy ux]);
			obj.CorrectionToPrecedingFrame = UxyPrev;
			data = translateFrame(obj, data, UxyPrev);
			
			% ALIGN WITH MEAN-FRAME (GLOBAL MOVING AVERAGE)
			moving = single(data(rowSubs, colSubs));
			fixed = single(obj.FixedMean(rowSubs, colSubs));
			[uy, ux] = getSubWinDisplacement(moving, fixed);
			UxyMean = applyTranslationLimits(obj, [uy ux]);
			obj.CorrectionToMovingAverage = UxyMean;
			
			% CHECK VALIDITY OF ALIGNMENT WITH MEAN-FRAME BEFORE APPLYING
			if all((abs(UxyMean + UxyPrev) - min(abs(UxyPrev),abs(UxyMean))) > -1) %all(abs(UxyMean) <= max(abs(UxyPrev),[1 1]))
				% (this check must be true IF the previous frame was successfully aligned to mean)
				Uxy = UxyPrev + UxyMean;
				data = translateFrame(obj, data, UxyMean);
			else
				Uxy = UxyPrev;
				fprintf('only using previous shift\n')
			end
			obj.FixedPrevious = data;
			obj.LastCorrection = Uxy;
			if isa(Uxy,'gpuArray')
				Uxy = gather(Uxy);
			end
			
			% SUBFUNCTIONS
			function [xcRow, xcCol] = getSubWinDisplacement(moving, fixed)
				% Returns the row & column shift that one needs to apply to MOVING to align with FIXED
				moving = moving  .* antiEdgeWin;
				fixed = fixed  .* antiEdgeWin;
				fMoving = fft2(moving);
				fFixed = fft2(fixed);
				% 				fMoving = fft2(rot90(moving,2), freqWinSize, freqWinSize);
				% 				fFixed = fft2(fixed, freqWinSize, freqWinSize);
				fX = fFixed .* conj(fMoving);
				xc = fftshift(ifft2( fX ./ max(abs(fMoving),abs(fFixed)), 'symmetric'));
				xc(~xcMask) = 0;
				[~, idx] = max(xc(:));
				[maxRow, maxCol] = ind2sub(size(xc), idx);
				% SUBPIXEL
				y = single((maxRow-2) : (maxRow+2));
				yq = single(y(1):(1/subpix):y(end));
				x = single((maxCol-2) : (maxCol+2));
				xq = single(x(1):(1/subpix):x(end));
				[X,Y] = meshgrid(x,y);
				[Xq,Yq] = meshgrid(xq,yq);
				% 				xcSubPix = spGaussFilt(interp2(X,Y, xc(y,x)./maxval, Xq, Yq, 'linear')); % gputimeit -> .0028
				% 				xcSubPix = interp2(X,Y, xc(y,x), Xq, Yq, 'linear'); % gputimeit -> .0028
				% 				xcSubPix = imgaussfilt(interp2(X,Y, xc(y,x), Xq, Yq, 'linear'), 5, 'Padding', 'replicate');%TODO find best size or use imfilter
				xcSubPix = imfilter(interp2(X,Y, xc(y,x), Xq, Yq, 'linear'), double(ones(subpix,'like',xc)), 'replicate');
				%TODO: Use polyfit instead -> ORRRRRRRRRR, could definitely speed this up with custom GPU kernel
				[~, idx] = max(xcSubPix(:));
				maxRow = Yq(idx);
				maxCol = Xq(idx);
				xcRow = maxRow - subCenter;
				xcCol = maxCol - subCenter;
			end
			% 			function subwin = padAndFiltSubwin(subwin)
			% 				subwin(padIdx, :) = 0;
			% 				subwin(:, padIdx) = 0;
			% 				subwin = subWinGaussFilt(subwin);
			% 			end
		end
		function Uxy = applyTranslationLimits(obj, Uxy)
			pThrottle = .95;
			% CHECK INTER-FRAME SMOOTHNESS
			lastUxy = cast(obj.LastCorrection, 'like', Uxy);
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
		function tuneInteractive(~)
		end
		function tuneAutomated(~)
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
		function setupRigidRegistration(obj)
			
			% GET SUBSCRIPTS
			subsCenteredOn = @(csub,n) (floor(csub-n/2+1):floor(csub+n/2))';
			nRows = obj.FrameSize(1);
			nCols = obj.FrameSize(2);
			
			% CALCULATE WINDOW SIZE THAT OPTIMIZES FFT
			subWinSize = min([min(obj.FrameSize)*2/3 ; max(obj.FrameSize)/2]);
			subWinSize = 2^(nextpow2(subWinSize));
			if any(subWinSize > [nRows nCols])
				subWinSize = 2^(nextpow2(subWinSize)-1);
			end
			obj.SubWinSize = subWinSize;
			
			% SUBSCRIPTS FOR SELECTION OF SUB-WINDOWS FOR ALIGNMENT
			rowSubs = subsCenteredOn(floor(nRows/2), subWinSize);
			colSubs =  subsCenteredOn(floor(nCols/2), subWinSize);
			
			obj.SubWinSubscripts = onGpu(obj, [rowSubs, colSubs]);
			
			% MAKE FILTER FOR SMOOTHING SUBWINDOWS BEFORE TAKING FFT
			% 			sigma = 3;
			% 			obj.SubWindowFilterFcn = obj.constructLowPassFilter(subWinSize, sigma);
			
			% WINDOWING FUNCTION
			obj.SubWinAntiEdgeWin = onGpu(obj, single(hann(subWinSize) * hann(subWinSize)'));
			
			% MAKE MASK FOR EXCLUDING INAPPROPRIATE RESULTS OF FFT EDGE-EFFECTS
			% 						fsSize = length(obj.SubWinSubscripts) + length(obj.SubWinSubscripts);
			fsSize = length(obj.SubWinSubscripts);
			fsValid = 2*obj.MaxInterFrameTranslation;
			subCenter = floor(fsSize/2 + 1);
			% 			subCenter = ceil(fsSize/2);
			if obj.useGpu
				fss = gpuArray.colon(1,fsSize);
				obj.XcMask = gpuArray(bsxfun(@and, abs(subCenter-fss)<fsValid , abs(subCenter-fss')<fsValid ));
			else
				fss = 1:fsSize;
				obj.XcMask = bsxfun(@and, abs(subCenter-fss)<fsValid , abs(subCenter-fss')<fsValid );
			end
			
			% MAKE FILTER FOR SMOOTHING INTERPOLATED SUBPIXELATION
			sigma = obj.SubPixelPrecision/2;
			imSize = 4*(obj.SubPixelPrecision)+1; % obj.SubPixelPrecision*(obj.SubPixelPrecision/2 - 1)+1;
			obj.PeakFilterFcn = obj.constructLowPassFilter(imSize, sigma);
			
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




























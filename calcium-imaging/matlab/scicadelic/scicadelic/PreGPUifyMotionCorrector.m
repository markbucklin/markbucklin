classdef  (CaseInsensitiveProperties = true) MotionCorrector <  scicadelic.SciCaDelicSystem
	% MotionCorrector - uses phase-correlation to find and correct the rigid displacement of frames over time.
	
	
	% USER SETTINGS
	properties (Nontunable, PositiveInteger)
		SubPixelPrecision = 10
		MaxInterFrameTranslation = 50					% Limits pixel velocity
		MaxNumBufferedFrames = 200
		MotionMagDiffStableThreshold = 1			% The maximum magnitude of interframe displacement (in pixels) allowed for inclusion in moving average
		DoubleAlignmentThreshold = 5
		PeakSurroundRadius = 2;								% 1 or 2 should be sufficient
	end
	properties (Nontunable, Logical)
		CorrectedFramesOutputPort = true
		AdjunctFrameInputPort = false
		AdjunctFrameOutputPort = false
		CorrectionInfoOutputPort = false
		UseSmallSubWindow = false							% For frame-size 1024x1024, using a smaller window than the default (512x512) actually increases processing time, but for larger frame sizes, this option may help speed things up.
		UseMomentMethodPeakFit = true
		UseWeightedFrameCorr = false
	end
	properties (Nontunable)
		GlobalCorrelationMinThreshold = .75
	end
		
	% STATES
	properties (DiscreteState)
		CurrentFrameIdx
	end
	
	% OUTPUTS
	properties (SetAccess = protected)%TODO - move to parent class?
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
	properties (SetAccess = protected)
		FixedMin
		FixedMax
		FixedMean
		FixedReference
	end
	
	% PRIVATE VARIABLES
	properties (SetAccess = protected, Nontunable, Hidden)
		SubWinSize
		SubWinCenterRow
		SubWinCenterCol
		SubWinRowSubs
		SubWinColSubs
		SubWinAntiEdgeWin
		XcMask%remove
		PeakFilterFcn
	end
	properties (SetAccess = protected)%, Hidden)		
		UxyMostRecent = [0 0]
		% 		CorrectionToPrecedingFrame = [0 0]
		CorrectionToMovingAverage = [0 0]
		FrameCorrelationWeightedOutput
		FrameCorrelationUnweightedOutput
		StableFrameMostRecent
		FrameCorrelationPixelWeight		
	end
	properties (SetAccess = protected)
		FixedFrameStatCollector
		CorrCoeffStatCollector
		PeakFitFcn
	end
	
	
	
	
	
	% CONSTRUCTOR
	methods
		function obj = MotionCorrector(varargin)
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
			
			[numRows, numCols, ~] = size(data);
			checkInput(obj, data);
			obj.TuningImageDataSet = [];
			
			obj.FixedFrameStatCollector = scicadelic.StatisticCollector;
			obj.CorrCoeffStatCollector = scicadelic.StatisticCollector;			
			setPrivateProps(obj)
			setupRigidRegistration(obj);
			
			obj.CurrentFrameIdx = 0;
			obj.UxyMostRecent = [0 0];
			obj.FixedMin = data(:,:,1);
			obj.FixedMax = data(:,:,1);
			obj.FixedMean = single(data(:,:,1));
			obj.FixedReference = data(:,:,1);
			
			% (NEW)
			if isempty(obj.FrameCorrelationPixelWeight)
				obj.FrameCorrelationPixelWeight = onGpu(obj, ones(numRows, numCols, 'single'));
			end
			
			if ~isempty(obj.GpuRetrievedProps)
				pushGpuPropsBack(obj)
			end
			fillDefaults(obj)
			setPrivateProps(obj)
		end
		function varargout = stepImpl(obj, Finput, varargin)
			
			if isempty(Finput)
				availableOutput = {[],[],[]};
			else
				
				% LOCAL VARIABLES
				F = single(Finput);
				numFrames = size(F,3);
				N = obj.CurrentFrameIdx;
				fRefLocal = obj.FixedReference; % on first round this is the first image
				fRefGlobal = obj.FixedMean;
				if isempty(fRefLocal);
					fRefLocal = F(:,:,1); % mean(F,3);
				end
				
				% COMPUTE DISPLACEMENT BETWEEN CURRENT REFERENCE FRAME & GLOBAL REFERENCE (MORE TEMPORALLY STEADY)
				if isempty(fRefGlobal);
					% 					fRefGlobal = F(:,:,1); % mean(F,3);
					uxyLocal2Global = zeros(1,2, 'like', Finput);
				else
					uxyLocal2Global = findFrameShift(obj, fRefLocal, fRefGlobal);
				end
				obj.CorrectionToMovingAverage = uxyLocal2Global;
				
				% COMPUTE DISPLACEMENT BETWEEN F (INPUT-STACK) & CURRENT REFERENCE (FIXED) FRAME
				uxyF2Local = findFrameShift(obj, F, fRefLocal);				
				
				% ADD LOCAL (short-term) & GLOBAL (long-term) DISPLACEMENT TO ALIGN F WITH GLOBAL-REFERENCE (FIXED-MEAN)
				Uxy = bsxfun(@plus, uxyF2Local, uxyLocal2Global);
				
				% APPLY TRANSLATION -> INTERPOLATE IF SUBPIXEL ACCURACY SPECIFIED
				F = applyFrameShift(obj, F, Uxy);
				
				% TRANSLATE ADJUNCT FRAMES IF SPECIFIED (TODO: combine with above?)
				if obj.AdjunctFrameInputPort ...
						&& (nargin > 2) ...
						&& ~all(Uxy == 0)
					Fadjunct = varargin{1};
					Fadjunct = applyFrameShift(obj, Fadjunct, Uxy);
				else
					Fadjunct = [];
				end
				
				% CHECK FRAME STABILITY & UPDATE LOCAL & GLOBAL REFERENCE FRAMES
				addStableUpdate2FixedFrameReference(obj, F)
								
				% ORGANIZE MOTION-CORRECTION INFORMATION IN STRUCTURE FOR OUTPUT
				obj.UxyMostRecent = Uxy(end,:);
				info = getCorrectionInfo(obj, Uxy);
				
				% UPDATE CURRENT STATES & STORED RESULTS (i.e. frame statistics)
				obj.CurrentFrameIdx = N + numFrames;
				obj.CorrectionInfo = info;
				updateRunningStatistics(obj)
				
				% ASSIGN OUTPUT
				availableOutput = {cast(F,'like',Finput), Fadjunct, info};
				
			end
			specifiedOutput = [...
				obj.CorrectedFramesOutputPort,...
				obj.AdjunctFrameOutputPort,...
				obj.CorrectionInfoOutputPort];
			varargout = availableOutput(specifiedOutput);
			
			
		end
		%TODO: function processTunedInputsImpl?
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
			% TODO
			obj.UxyMostRecent = [0 0];
			setPrivateProps(obj)
			setInitialState(obj)
		end
		function releaseImpl(obj)
			fetchPropsFromGpu(obj)
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
		function Uxy = findFrameShift(obj, movingInput, fixedInput)
			% Computes the mean frame displacement vector between unregistered frames MOVING (ND) &
			% registered frame FIXED (2D) using phase correlation.
			
			% COPY PROPERTIES TO LOCAL VARIABLES FOR FASTER REUSE
			subPix = obj.pSubPixelPrecision;
			swRowSubs = single(obj.SubWinRowSubs);
			swColSubs = single(obj.SubWinColSubs);
			centerRow = obj.SubWinCenterRow;
			centerCol = obj.SubWinCenterCol;
			antiEdgeWin = single(obj.SubWinAntiEdgeWin);
			[numRows, numCols, numFrames] = size(movingInput);
			frameSubs = onGpu(obj, single(reshape(1:numFrames, 1,1,numFrames)));
			
			
			% ============================================================
			% CONVERT TO FLOATING-POINT, & APPLY TAPERING WINDOW FUNCTION
			% ============================================================			
			if (numRows~=numel(swRowSubs)) || (numCols~=numel(swColSubs))	
				% (EXTRACT SUB-WINDOW IF SPECIFIED)
				moving = bsxfun(@times, single(movingInput(swRowSubs, swColSubs, :)), antiEdgeWin); % 3.8ms
				fixed = bsxfun(@times, single(fixedInput(swRowSubs, swColSubs, :)), antiEdgeWin); % .5ms				
			else
				moving = bsxfun(@times, single(movingInput), antiEdgeWin);
				fixed = bsxfun(@times, single(fixedInput), antiEdgeWin);				
			end
			
			% CALL PHASE-CORRELATION SUBFUNCTION
			[uy, ux] = peakOfPhaseCorrelationMatrix(moving, fixed);
			
			% VALIDITY CHECK? TODO...
			Uxy = [uy(:) ux(:)];
			
			
			
			% ============================================================
			% COMPUTE PHASE-CORRELATION IN FREQUENCY DOMAIN
			% ============================================================
			function [uy, ux] = peakOfPhaseCorrelationMatrix(moving, fixed)
				% Returns the row & column shift that one needs to apply to MOVING to align with FIXED
				%		-> XC = Phase-Correlation Matrix
				%		-> SW = Sub-Window
				%		-> PS = Peak-Surround
				
				% TRANSFORM TO FOURIER DOMAIN (FFT)
				fMoving = fft2(moving);		% 3.6 ms/call
				fFixed = fft2(fixed);			% 2.7 ms/call
				
				% MULTIPLY FIXED FRAME WITH CONJUGATE OF MOVING FRAMES
				fFM = bsxfun(@times, fFixed , conj(fMoving));
				
				% TRANSFORM BACK TO SPATIAL DOMAIN (IFT) AFTER NORMALIZATION (CROSS-CORRELATION FUNCTION -> XC)
				xc = fftshift(fftshift( ifft2( single(fFM ./ abs(fFM + eps(fFM))), 'symmetric'), 1),2);	% 25.6 ms/call
				
				% ESTIMATE THE PHASE-CORR NOISE-FLOOR & SHIFT XC FLOOR TO NEGATIVE RANGE
				[xcNumRows, xcNumCols, xcNumFrames] = size(xc);
				xcFrameMin = min(min( xc, [],1), [], 2);
				xc = log1p(bsxfun( @minus, xc, xcFrameMin)); % NEW -> LOG1P
				
				
				% ============================================================
				% FIND COARSE (INTEGER) SUBSCRIPTS OF PHASE-CORRELATION PEAK (INTEGER-PRECISION MAXIMUM)
				% ============================================================
				[xcNumRows, xcNumCols, xcNumFrames] = size(xc);
				R = obj.PeakSurroundRadius;
				Csize = 1+2*R;
				xcNumPixels = xcNumRows*xcNumCols;
				[~, xcMaxFrameIdx] = max(reshape(xc, xcNumPixels, xcNumFrames),[],1);
				xcMaxFrameIdx = reshape(xcMaxFrameIdx, 1, 1, xcNumFrames);
				[xcMaxRow, xcMaxCol] = ind2sub([xcNumRows, xcNumCols], xcMaxFrameIdx);
				
				
				
				% ============================================================
				% REFINE ESTIMATE TO SUBPIXEL ACCURACY BY INTERPOLATION, SURFACE-FITTING, OR KDE
				% ============================================================				
				if logical(subPix) && (subPix > 1)
					
					% CALCULATE LINEAR ARRAY INDICES FOR PIXELS SURROUNDING INTEGER-PRECISION PEAK
					peakDomain = -R:R;
					xcFrameIdx = reshape(xcNumPixels*(0:xcNumFrames-1),1,1,xcNumFrames);
					xcPeakSurrIdx = ...
						bsxfun(@plus, peakDomain(:),...
						bsxfun(@plus,peakDomain(:)' .* xcNumRows,...
						bsxfun(@plus,xcFrameIdx,...
						xcMaxFrameIdx)));
					C = reshape(xc(xcPeakSurrIdx),...
						Csize,Csize,xcNumFrames);
					
					% CHOOSE A METHOD FOR FITTING A SURFACE TO PIXELS SURROUNDING PEAK
					if isempty(obj.PeakFitFcn)
						bench = comparePeakFitFcn(C, ...
							@getPeakSubpixelOffset_MomentMethod, ...
							@getPeakSubpixelOffset_PolyFit);
						if bench.precise.t < (2*bench.fast.t)
							obj.PeakFitFcn = bench.precise.fcn;
						else
							obj.PeakFitFcn = bench.fast.fcn;
						end
						%TODO: save bench
					end
					
					% USE MOMENT METHOD TO CALCULATE CENTER POSITION OF A GAUSSIAN FIT AROUND PEAK - OR USE LEAST-SQUARES POLYNOMIAL SURFACE FIT
					[spdy, spdx] = obj.PeakFitFcn(C);
					% 						[spdy, spdx] = getPeakSubpixelOffset_MomentMethod(C);		% 10.5 ms/call
					uy = reshape(swRowSubs(xcMaxRow), 1,1,xcNumFrames) + spdy - centerRow - 1;
					ux = reshape(swColSubs(xcMaxCol), 1,1,xcNumFrames) + spdx - centerCol - 1;
					
					% TODO: ROUND TO DESIRED SUBPIXEL ACCURACY
					
				else
					% SKIP SUB-PIXEL CALCULATION
					uy = reshape(swRowSubs(xcMaxRow), 1,1,numFrames) - centerRow - 1;
					ux = reshape(swColSubs(xcMaxCol), 1,1,numFrames) - centerCol - 1;
					
				end
				
				
				
				
				
				% ===  BENCHMARKING FUNCTION TO CHOOSE WHICH FUNCTION TO PERFORM ===
				function bench = comparePeakFitFcn(c, fastFcn, preciseFcn)
					
					fast.fcn = fastFcn;
					precise.fcn = preciseFcn;
					
					if obj.pUseGpu
						fast.t = gputimeit(@() fast.fcn(c), 2);
						precise.t = gputimeit(@() precise.fcn(c), 2);
					else
						fast.t = timeit(@() fast.fcn(c), 2);
						precise.t = timeit(@() precise.fcn(c), 2);
					end
					
					fast.dydx = fast.fcn(c);
					precise.dydx = precise.fcn(c);
					
					bench.fast = fast;
					bench.precise = precise;
					bench.sse = sum((bench.precise.dydx(:) - bench.fast.dydx(:)).^2);
					bench.dt = (bench.precise.t - bench.fast.t) / bench.fast.t;
					
				end
				
				
				% ===  MOMENT-METHOD FOR ESTIMATING POSITION OF A GAUSSIAN FIT TO PEAK ===
				function [spdy, spdx] = getPeakSubpixelOffset_MomentMethod(c)
					cSum = sum(sum(c));
					d = size(c,1);
					r = floor(d/2);
					spdx = .5*(bsxfun(@rdivide, ...
						sum(sum( bsxfun(@times, (1:d), c))), cSum) - r ) ...
						+ .5*(bsxfun(@rdivide, ...
						sum(sum( bsxfun(@times, (-d:-1), c))), cSum) + r );
					spdy = .5*(bsxfun(@rdivide, ...
						sum(sum( bsxfun(@times, (1:d)', c))), cSum) - r ) ...
						+ .5*(bsxfun(@rdivide, ...
						sum(sum( bsxfun(@times, (-d:-1)', c))), cSum) + r );
					
				end
								
				% ===  LEAST-SQUARES FIT OF POLYNOMIAL FUNCTION TO PEAK ===
				function [spdy, spdx] = getPeakSubpixelOffset_PolyFit(c)
					% POLYNOMIAL FIT, c = Xb
					[cNumRows, cNumCols, cNumFrames] = size(c);
					d = cNumRows;
					r = floor(d/2);
					[xg,yg] = meshgrid(-r:r, -r:r);
					x=xg(:);
					y=yg(:);
					X = [ones(size(x),'like',x) , x , y , x.*y , x.^2, y.^2];
					b = X \ reshape(c, cNumRows*cNumCols, cNumFrames);
					if (cNumFrames == 1)
						spdx = (-b(3)*b(4)+2*b(6)*b(2)) / (b(4)^2-4*b(5)*b(6));
						spdy = -1 / ( b(4)^2-4*b(5)*b(6))*(b(4)*b(2)-2*b(5)*b(3));
					else
						spdx = reshape(...
							(-b(3,:).*b(4,:) + 2*b(6,:).*b(2,:))...
							./ (b(4,:).^2 - 4*b(5,:).*b(6,:)), ...
							1, 1, cNumFrames);
						spdy = reshape(...
							-1 ./ ...
							( b(4,:).^2 - 4*b(5,:).*b(6,:)) ...
							.* (b(4,:).*b(2,:) - 2*b(5,:).*b(3,:)), ...
							1, 1, cNumFrames);
					end
					spdy = real(spdy);
					spdx = real(spdx);
				end
			end
			
			
		end
		function [C, varargout] = findFrameCorrelationCoefficient(obj, F, Fref)
			
			% IF SECOND OUTPUT IS REQUESTED -> ALSO RETURNS WEIGHTED CORR
			computeWeightedCorr = (nargout > 1);
			
			% CALCULATE UNWEIGHTED FRAME-CORRELATION COEFFICIENT
			if obj.UseGpu
				% CALL EXTERNAL FUNCTION THAT CONSTRUCTS & RUNS A CUDA KERNEL
				C = frameCorrGpu(F, Fref);
				
			else
				% USE BUILTIN FUNCTION
				C = corr2(F, Fref);
				
			end
			
			% RETRIEVE RUNNING STATISTIC ACCUMULATORS
			ffStat = obj.FixedFrameStatCollector;
			ccStat = obj.CorrCoeffStatCollector;
			
			% ALSO COMPUTE WEIGHTED FRAME-CORRELATION (ONLY IF SPECIFIED)
			if ~computeWeightedCorr
				Cuse = C;
				
			else
				
				% UPDATE PIXEL-WEIGHT ARRAY FOR CALCULATING WEIGHTED FRAME-CORRELATION (IF REQUESTED)
				frameSkew = ffStat.Skewness;
				frameSkewLim = min(max(frameSkew(:)),-min(frameSkew(:)));
				frameSkewComponent = 1-erf(pi*min( 1, bsxfun(@rdivide, abs(frameSkew), frameSkewLim)));
				ccPixelWeight = frameSkewComponent;
				obj.FrameCorrelationPixelWeight = ccPixelWeight;
				
				% RUN SIMILAR TO UNWEIGHTED ABOVE
				if obj.UseGpu
					Cweighted = frameCorrGpu(F, Fref, ccPixelWeight); % 8ms (no weight) vs 12ms (with weight)
				else
					% USE BUILTIN FUNCTION
					Cweighted = corr2(F, bsxfun(@times, Fref, ccPixelWeight));
				end
				
				% OUTPUT
				varargout{1} = Cweighted;
				Cuse = Cweighted;
								
			end
			
			% UPDATE RUNNING STATISTIC -> USED TO DETERMINE 'NON-NORMAL' FLUCTUATIONS
			step(ccStat, reshape(Cuse, 1,1,numel(Cuse)));
			
			
		end
		function F = applyFrameShift(obj, F, Uxy)
			
			% ---------->>> TODO: WOULD BY MUCH MUCH FASTER WITH A GPU KERNEL!!!!!!!!!!!!!!!!!!
			% ---------->>> TODO: WOULD BY MUCH MUCH FASTER WITH A GPU KERNEL!!!!!!!!!!!!!!!!!!
			dataisongpu = isa(F,'gpuArray');
			
			[numRows, numCols, numFrames] = size(F);
			
			% TODO
			if dataisongpu
				rowSubs = reshape(single(gpuArray.colon(1,numRows)), numRows,1);
				colSubs = reshape(single(gpuArray.colon(1,numCols)), 1, numCols);
				frameSubs = reshape(single(gpuArray.colon(1,numFrames)), 1,1,numFrames);
				Ffp = single(F);
				
			else
				rowSubs = reshape(colon(1,numRows), numRows,1);
				colSubs = reshape(colon(1,numCols), 1, numCols);
				frameSubs = reshape(colon(1,numFrames), 1,1,numFrames);
				Ffp = double(F);
				
			end
			
			% INTERPOLATE OVER NEW GRID SHIFTED BY Ux & Uy
			ux = reshape(Uxy(:,2), 1,1,numFrames);
			uy = reshape(Uxy(:,1), 1,1,numFrames);
			
			if numFrames > 1
				[Y,X,Z] = ndgrid(rowSubs, colSubs, frameSubs);
				Xq = bsxfun(@minus, X, ux);
				Yq = bsxfun(@minus, Y, uy);
				Zq = Z;
				Ffp = interpn( Y,X,Z, Ffp, Yq, Xq, Zq, 'linear', -1); % Ffp = interpn( X,Y,Z, Ffp, Xq, Yq, Zq, 'linear', -1);
			else
				try
					Ffp = interp2( Ffp, colSubs+ux, rowSubs+uy, 'linear', -1); % Ffp = interp2( Ffp, rowSubs-uy, colSubs-ux, 'linear', -1);
				catch me
					showError(me)
				end
			end
			
			% REPLACE MISSING PIXELS ALONG EDGE			
			dMask = Ffp < 0;
			% 			Fmean = repmat(obj.FixedMean, 1,1,numFrames);
			% 			Ffp(dMask) = Fmean(dMask);
			Ffp = Ffp + bsxfun(@times, cast(obj.FixedMean + 1,'like',Ffp), cast(dMask,'like',Ffp));
			F = cast(Ffp,'like', F);
			
		end
		function addStableUpdate2FixedFrameReference(obj, F)
			
			ffStat = obj.FixedFrameStatCollector;
			ccStat = obj.CorrCoeffStatCollector;
			
			% COMPUTE FRAME-CORRELATION COEFFICIENTS BETWEEN 'LOCALLY ALIGNED' FRAMES & FIXED-AVERAGE
			if obj.UseWeightedFrameCorr
				[Cuw, Cw] = findFrameCorrelationCoefficient(obj, F, obj.FixedMean);
				C = Cw;				
				obj.FrameCorrelationUnweightedOutput = Cuw(:);
				obj.FrameCorrelationWeightedOutput = Cw(:);
				
			else
			
				C = findFrameCorrelationCoefficient(obj, F, obj.FixedMean);
				obj.FrameCorrelationUnweightedOutput = C(:);				
				
			end
			
			% UPDATE STABILITY THRESHOLD & DETERMINE STABLE FRAMES (RELATIVE TO GLOBAL AVERAGE)
			globalCorrThresh = max(...
				obj.GlobalCorrelationMinThreshold ,...
				ccStat.Mean + ccStat.StandardDeviation.*ccStat.Skewness);%TODO: check
			kStable = bsxfun(@gt, C(:) , globalCorrThresh);
			
			% STORE CORRELATION-COEFFICIENTS & RESULTANT STABILITY ESTIMATE
			obj.StableFrameMostRecent = kStable;
			
			% ACCUMULATE STABLE FRAMES IN SEQUENTIAL MEAN (+ other statistics) & UPDATE LOCAL-FIXED-REFERENCE FRAME (current/recent)
			if any(kStable)
				fixedUpdate = F(:,:,kStable);
				obj.FixedReference = F(:,:,find(kStable,1,'last'));
				
			else
				% USE SINGLE MOST STABLE FRAME TO ADD PARTIAL UPDATE TO LOCAL & GLOBAL FIXED FRAMES
				[~, bestCorrIdx] = max(C(:));
				if ~isempty(bestCorrIdx)
					fixedUpdate = F(:,:,bestCorrIdx);
					obj.FixedReference = .75*obj.FixedReference + .25*fixedUpdate;	% TODO: COME UP WITH BETTER COMPOSITING FUNCTION
				else
					fixedUpdate = F;
				end
			end
			
			% UPDATE FIXED-FRAME STATISTIC-ACCUMULATOR
			step(ffStat, fixedUpdate);
			
			
		end
		function updateRunningStatistics(obj)
			
			fixedFrameStat = obj.FixedFrameStatCollector;
			
			% FIXED MEAN
			obj.FixedMean = fixedFrameStat.Mean;
			
			% FIXED MAX & MIN
			obj.FixedMax = fixedFrameStat.Max;
			obj.FixedMin = fixedFrameStat.Min;
			
			
		end
		function info = getCorrectionInfo(obj, Uxy)
			
			% BRING RESULTS TO CPU FOR SIMPLER INCLUSION IN STRUCTURED OUTPUT
			dUxy = onCpu(obj, bsxfun(@minus, Uxy , cat(1, obj.UxyMostRecent, Uxy(1:end-1,:)))); % Uxy(:,:,1:end-1))));
			Uxy = onCpu(obj, Uxy);
			C = onCpu(obj, obj.FrameCorrelationUnweightedOutput(:));
			Cw = onCpu(obj, obj.FrameCorrelationWeightedOutput(:));
			bStable = onCpu(obj, obj.StableFrameMostRecent(:));
			
			% SPLIT X-Y COMPONENTS OF APPLIED CORRECTION AND CALCULATE MAGNITUDE/DIRECTION
			uy = Uxy(:,1);
			ux = Uxy(:,2);
			umag = hypot(ux,uy);
			udir = atan2d(uy,ux);
			
			% ALSO SAVE DIFFERENTIAL DISPLACEMENT (1st Moment?)
			duy = dUxy(:,1);
			dux = dUxy(:,2);
			dmag = hypot(dux, duy);
			ddir = atan2d(duy, dux);
			
			% FILL INFO STRUCTURE
			info.ux = ux;
			info.uy = uy;
			info.dir = udir;
			info.mag = umag;
			info.dux = dux;
			info.duy = duy;
			info.ddir = ddir;
			info.dmag = dmag;
			info.cc = C;
			info.ccw = Cw;
			info.stable = bStable;
			
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
		function setupRigidRegistration(obj)
			
			% GET SUBSCRIPTS
			subsCenteredOn = @(csub,n) (floor(csub-n/2+1):floor(csub+n/2))';
			numRows = obj.FrameSize(1);
			numCols = obj.FrameSize(2);
			
			% CALCULATE WINDOW SIZE THAT OPTIMIZES FFT
			% 			subWinSize = min([min(obj.FrameSize)*2/3 ; max(obj.FrameSize)/2]);
			subWinSize = min(obj.FrameSize(1:2));
			if obj.UseSmallSubWindow
				subWinSize = 2^(nextpow2(subWinSize)-1);
			else
				subWinSize = 2^(nextpow2(subWinSize));
			end
			if any(subWinSize > [numRows numCols])
				subWinSize = 2^(nextpow2(subWinSize)-1);
			end
			obj.SubWinCenterRow = floor(numRows/2);% + 1; % removed +1 as working version didn't use it
			obj.SubWinCenterCol = floor(numCols/2);% + 1;
			obj.SubWinSize = subWinSize;
			
			% STORE SUBSCRIPTS FOR SELECTION OF SUB-WINDOWS FOR ALIGNMENT
			obj.SubWinRowSubs = onGpu(obj, subsCenteredOn(obj.SubWinCenterRow, subWinSize)); %TODO: ceil?
			obj.SubWinColSubs = onGpu(obj, subsCenteredOn(obj.SubWinCenterCol, subWinSize));
			
			% CONSTRUCT WINDOWING FUNCTION/MASK TO REDUCE EDGE-EFFECTS OF FFT
			obj.SubWinAntiEdgeWin = onGpu(obj, single(hann(subWinSize) * hann(subWinSize)'));
			
			% MAKE MASK FOR EXCLUDING INAPPROPRIATE RESULTS OF FFT EDGE-EFFECTS
			fsSize = length(obj.SubWinRowSubs);
			fsValid = 2*obj.MaxInterFrameTranslation;
			subCenter = floor(fsSize/2 - 1);
			% 			subCenter = ceil(fsSize/2);
			% 			if obj.useGpu
			% 				fss = gpuArray.colon(1,fsSize);
			% 				obj.XcMask = gpuArray(bsxfun(@and, abs(subCenter-fss)<fsValid , abs(subCenter-fss')<fsValid ));
			% 			else
			% 				fss = 1:fsSize;
			% 				obj.XcMask = bsxfun(@and, abs(subCenter-fss)<fsValid , abs(subCenter-fss')<fsValid );
			% 			end
			
			% MAKE FILTER FOR SMOOTHING INTERPOLATED SUBPIXELATION (not currently implemented)
			sigma = obj.SubPixelPrecision/2;
			imSize = 2*(obj.SubPixelPrecision)+1; % obj.SubPixelPrecision*(obj.SubPixelPrecision/2 - 1)+1;
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






















% [~, rowIdx1] = max(max(xc, [],1), [], 2);
% [~, colIdx1] = max(max(xc, [],2), [], 1);
% [~, rowIdx2] = max(max(rot90(xc), [],1), [], 2);
% [~, colIdx2] = max(max(rot90(xc), [],2), [], 1);
% maxRowSub = ceil((rowIdx1 + rowIdx2)*.5);
% maxColSub = ceil((colIdx1 + colIdx2)*.5);

%
% [colMaxVal, colMaxIdx] = max(xc,[],1); % colmaxidx = idx of row with max pixel in column
% [rowMaxVal, rowMaxIdx] = max(xc,[],2); % rowmaxidx = idx of column with max value in each row
% [colRowMaxVal, colRowMaxIdx] = max(colMaxVal, [], 2); % colRowMaxIdx -> rowSub
% [rowColMaxVal, rowColMaxIdx] = max(rowMaxVal, [], 1); % rowColMaxIdx -> colSub

% [~, rowIdx1] = max(max(xcSubPix, [],1), [], 2);
% [~, colIdx1] = max(max(xcSubPix, [],2), [], 1);
% [~, rowIdx2] = max(max(rot90(xcSubPix), [],1), [], 2);
% [~, colIdx2] = max(max(rot90(xcSubPix), [],2), [], 1);
% maxRowSub = yq(ceil((rowIdx1 + rowIdx2)*.5));
% maxColSub = xq(ceil((colIdx1 + colIdx2)*.5));



% [numSubWinRows, numSubWinCols, ~] = size(xc);
% numSubWinPixels = numSubWinRows*numSubWinCols;
% xcCol = reshape(xc, numSubWinPixels, numFrames);
% [~, xcMaxIdx] = max(xcCol,[],1);
% xcMaxIdx = reshape(xcMaxIdx, 1, 1, numFrames);
% xcPeakSurrIdx = bsxfun(@plus, [-1;0;1],...
% 	bsxfun(@plus,[-numSubWinRows,0,numSubWinRows],...
% 	bsxfun(@plus,reshape(numSubWinPixels*(0:numFrames-1),1,1,numFrames),...
% 	xcMaxIdx)));
% xcPeakSurr = reshape(xc(xcPeakSurrIdx), 3,3,numFrames);
% [maxRowSub, maxColSub] = ind2sub([numSubWinRows, numSubWinCols], xcMaxIdx);
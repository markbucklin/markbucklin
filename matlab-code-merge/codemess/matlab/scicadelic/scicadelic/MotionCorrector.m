classdef  (CaseInsensitiveProperties = true) MotionCorrector <  scicadelic.SciCaDelicSystem
	% MotionCorrector - uses phase-correlation to find and correct the rigid displacement of frames over time.
	
	
	% USER SETTINGS
	properties (Nontunable, PositiveInteger)
		SubPixelPrecision = 25
		JerkSuppressionThreshold = 10;
	end
	properties (Nontunable, Logical)
		CorrectedFramesOutputPort = true
		CorrectionInfoOutputPort = true
		AdjunctFrameInputPort = false
		AdjunctFrameOutputPort = false
		UseSmallSubWindow = false
		UseWeightedFrameCorr = false
		UseLog = false
		UseExp = false
		UseLocalGlobal = false
		SuppressJerkyCorrection = true
	end
	properties (Nontunable)
		GlobalCorrelationMinThreshold = .70
	end
	
	% STATES
	properties (DiscreteState)
		CurrentFrameIdx
	end
	
	% OUTPUTS
	properties (SetAccess = protected)
		CorrectionInfo
		ErrorRate
	end
	
	% PRIVATE COPIES
	properties (SetAccess = protected, Hidden, Nontunable)
		pSubPixelPrecision
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
	end
	properties (SetAccess = protected)%, Hidden)
		UxyMostRecent = [0 0]
		CorrectionToMovingAverage = [0 0]
		FrameCorrelationWeightedOutput
		FrameCorrelationUnweightedOutput
		StableFrameMostRecent
		FrameCorrelationPixelWeight
	end
	properties (SetAccess = protected)
		FixedFrameStatCollector % removed -> ran into bugs running same function with different datatype..?
		CorrCoeffStatCollector
		PeakFitFcn
	end
	
	
	
	
	
	% CONSTRUCTOR
	methods
		function obj = MotionCorrector(varargin)
			parseConstructorInput(obj,varargin(:));
			setProperties(obj,nargin,varargin{:});
		end
	end
	
	% BASIC INTERNAL SYSTEM METHODS
	methods (Access = protected)
		function setupImpl(obj,data,~)
			
			[numRows, numCols, ~] = size(data);
			checkInput(obj, data);
			obj.TuningImageDataSet = [];
			
			% 			obj.FixedFrameStatCollector = scicadelic.StatisticCollector;
			% 			obj.CorrCoeffStatCollector = scicadelic.StatisticCollector;
			setPrivateProps(obj)
			setupRigidRegistration(obj);
			
			obj.CurrentFrameIdx = 0;
			obj.UxyMostRecent = [0 0];
			obj.FixedMin = single(data(:,:,1));
			obj.FixedMax = single(data(:,:,1));
			obj.FixedMean = single(data(:,:,1));
			obj.FixedReference = single(data(:,:,1));
			
			% (NEW)
			if isempty(obj.FrameCorrelationPixelWeight)
				obj.FrameCorrelationPixelWeight = onGpu(obj, ones(numRows, numCols, 'single'));
			end
			if isempty(obj.ErrorRate)
				obj.ErrorRate = 0;
			end
			if isempty(obj.CurrentFrameIdx)
				obj.CurrentFrameIdx = 0;
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
					fRefGlobal = single(mean(F, 3));
					% 					uxy2Global = zeros(1,2, 'like', F);
				end
				
				if obj.UseLocalGlobal
					% ALIGN INPUT TO GLOBAL REFERENCE FRAME
					uxy2Global = findFrameShift(obj, F, fRefGlobal);
					obj.CorrectionToMovingAverage = uxy2Global;
					F = applyFrameShift(obj, F, uxy2Global);
					
					% ALIGN GLOBALLY ALIGNED INPUT TO LOCAL REFERENCE FRAME
					uxy2Local = findFrameShift(obj, F, fRefLocal);
					F = applyFrameShift(obj, F, uxy2Local);
					
					% ADD LOCAL (short-term) & GLOBAL (long-term) DISPLACEMENT
					Uxy = bsxfun(@plus, uxy2Local, uxy2Global);
					
				else
					% ALIGN ONLY LOCAL REFERENCE TO GLOBAL REFERENCE
					uxy2Global = findFrameShift(obj, fRefLocal, fRefGlobal);
					obj.CorrectionToMovingAverage = uxy2Global;
					
					% COMPUTE DISPLACEMENT BETWEEN F (INPUT-STACK) & CURRENT REFERENCE (FIXED) FRAME
					uxy2Local = findFrameShift(obj, F, fRefLocal);
					
					% ADD LOCAL (short-term) & GLOBAL (long-term) DISPLACEMENT TO ALIGN F WITH GLOBAL-REFERENCE (FIXED-MEAN)
					Uxy = bsxfun(@plus, uxy2Local, uxy2Global);
					
					% SUPPRESS MASSIVE CORRECTIONS THAT ARE LIKELY ERRORS
					Uxy = suppressJerks(obj, Uxy);
					
					% APPLY TRANSLATION -> INTERPOLATE IF SUBPIXEL ACCURACY SPECIFIED
					F = applyFrameShift(obj, F, Uxy);
				end
				
				
				
				% TRANSLATE ADJUNCT FRAMES IF SPECIFIED (TODO: combine with above?)
				if obj.AdjunctFrameInputPort ...
						&& (nargin > 2) 
%                     ...
% 						&& ~all(gather(Uxy(:)) == 0)
					Fadjunct = varargin{1};
					Fadjunct = applyFrameShift(obj, Fadjunct, Uxy);
				else
					Fadjunct = [];
				end
				
				% CHECK FRAME STABILITY & UPDATE LOCAL & GLOBAL REFERENCE FRAMES
				addStableUpdate2FixedFrameReference(obj, F)
				
				% ORGANIZE MOTION-CORRECTION INFORMATION IN STRUCTURE FOR OUTPUT
				info = getCorrectionInfo(obj, Uxy);
				
				% UPDATE CURRENT STATES & STORED RESULTS
				obj.CurrentFrameIdx = N + numFrames;
				obj.CorrectionInfo = info;
				% 				updateRunningStatistics(obj)
				
				% ASSIGN OUTPUT
				if nargout % NEW
					availableOutput = {cast(F,'like',Finput), Fadjunct, info};
				end
				
			end
			
			if nargout % NEW
				specifiedOutput = [...
					obj.CorrectedFramesOutputPort,...
					obj.AdjunctFrameOutputPort,...
					obj.CorrectionInfoOutputPort];
				outputArgs = availableOutput(specifiedOutput);
				varargout = outputArgs(1:nargout);
			end
			
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
			obj.ErrorRate = 0;
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
			antiEdgeWin = single(obj.SubWinAntiEdgeWin);
			[numRows, numCols, numFrames] = size(movingInput);
			frameSubs = onGpu(obj, single(reshape(1:numFrames, 1,1,numFrames)));
			
			% CONVERT TO FLOATING-POINT, & APPLY TAPERING WINDOW FUNCTION
			if obj.UseSmallSubWindow %(numRows~=numel(swRowSubs)) || (numCols~=numel(swColSubs))
				% (EXTRACT SUB-WINDOW IF SPECIFIED)
				rowSubs = single(obj.SubWinRowSubs);
				colSubs = single(obj.SubWinColSubs);
				centerRow = obj.SubWinCenterRow;
				centerCol = obj.SubWinCenterCol;
				moving = bsxfun(@times, single(movingInput(rowSubs, colSubs, :)), antiEdgeWin); % 3.8ms
				fixed = bsxfun(@times, single(fixedInput(rowSubs, colSubs, :)), sqrt(abs(antiEdgeWin))); % .5ms
			else
				rowSubs = 1:numRows;
				colSubs = 1:numCols;
				centerRow = floor(numRows/2)+1;
				centerCol = floor(numCols/2)+1;
				moving = bsxfun(@times, single(movingInput), antiEdgeWin);
				fixed = bsxfun(@times, single(fixedInput), sqrt(abs(antiEdgeWin)));
			end
			
			% APPLY EXP OR LOG TO SCALED FRAME IF SPECIFIED
			useExp = obj.UseExp;
			useLog = obj.UseLog;
			if useExp || useLog
				% 				fmax = max(fixed(:));
				if useExp
					fixed = expnorm(fixed);
					moving = expnorm(moving);
					% 					fixed = exp((fixed - fmax)/fmax);
					% 					moving = exp((moving - fmax)/fmax);
				else
					fixed = lognorm(fixed);
					moving = lognorm(moving);
				end
			end
			
			% CALL PHASE-CORRELATION SUBFUNCTION
			[uy, ux] = peakOfPhaseCorrelationMatrix(moving, fixed);
			
			% VALIDITY CHECK? TODO...
			Uxy = [uy(:) ux(:)];
			
			
			% #############################################################
			% COMPUTE PHASE-CORRELATION IN FREQUENCY DOMAIN ===============
			% #############################################################
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
				fFMmean = mean(abs(fFM(:)));
				
				% TRANSFORM BACK TO SPATIAL DOMAIN (IFT) AFTER NORMALIZATION (CROSS-CORRELATION FUNCTION -> XC)
				XC = fftshift(fftshift( ifft2( single(fFM ./ abs(fFM + fFMmean + eps(fFM))), 'symmetric'), 1),2);	% 25.6 ms/call
				XC = XC./max(XC(:));
				
				% REFINE ESTIMATE TO SUBPIXEL ACCURACY BY INTERPOLATION, SURFACE-FITTING, OR KDE
				if logical(subPix) && (subPix > 1)
					
					[uy, ux] = findPeakGaussianKernelDensityRunGpuKernel(XC, subPix);
					% 					[uy,ux] = findPeakMomentMethod(XC);
					
				else
					% FIND COARSE (INTEGER) SUBSCRIPTS OF PHASE-CORRELATION PEAK (INTEGER-PRECISION MAXIMUM)
					[xcNumRows, xcNumCols, xcNumFrames] = size(XC);
					xcNumPixels = xcNumRows*xcNumCols;
					[~, xcMaxFrameIdx] = max(reshape(XC, xcNumPixels, xcNumFrames),[],1);
					xcMaxFrameIdx = reshape(xcMaxFrameIdx, 1, 1, xcNumFrames);
					[xcMaxRow, xcMaxCol] = ind2sub([xcNumRows, xcNumCols], xcMaxFrameIdx);
					uy = reshape(rowSubs(xcMaxRow), 1,1,numFrames) - centerRow;
					ux = reshape(colSubs(xcMaxCol), 1,1,numFrames) - centerCol;
					
				end
				
			end
			function f = expnorm(f)
				fmax = max(max(max(f,[],1),[],2),[],3);
				fmin = min(min(min(f,[],1),[],2),[],3);
				expInvScale = cast(1/(1-exp(-1)), 'like', f);
				expInvShift = cast(exp(-1), 'like', f);
				frange = fmax - fmin;
				f = bsxfun(@minus, f, fmin);
				f = expInvScale * (exp( - ...
					bsxfun(@rdivide,...
					bsxfun(@minus, frange, f), ...
					frange)) ...
					- expInvShift);
				
			end
			function f = lognorm(f)
				fmax = max(max(max(f,[],1),[],2),[],3);
				fmin = min(min(min(f,[],1),[],2),[],3);
				f = bsxfun(@minus, f, fmin);
				frange = fmax - fmin;
				f = bsxfun(@minus, f, fmin);
				f = log( ...
					bsxfun(@rdivide,...
					frange, ...
					abs(bsxfun(@minus, frange, f))));
				
			end
		end
		function Uxy = suppressJerks(obj, Uxy)
			
			numFrames = size(Uxy,1);
			errThresh = obj.JerkSuppressionThreshold;
			errRate = obj.ErrorRate;
			try
				
				if obj.SuppressJerkyCorrection && (numFrames >= 8)
					Ut = diff(Uxy,[],1);
					% 				[~, Ut] = gradient(Uxy);
					utErr = median(abs(Ut)) + 1;
					% 			Uxymed = median(Uxy,1);
					isErrFrame = bsxfun(@gt, abs(Ut), errThresh*utErr);
					errCount = nnz(isErrFrame);
					idxErr = find( any(isErrFrame,2));
					k = ceil(numFrames/2);
					
					while ~isempty(idxErr) && k>1
						if idxErr(1) == 1
							uxyLast = [obj.CorrectionInfo.uy obj.CorrectionInfo.ux];
							if ~isempty(uxyLast)
								Uxy(1, :) = (uxyLast + Uxy(2, :)) ./ 2;
							else
								Uxy(1, :) = Uxy(2, :);
							end
						elseif idxErr(end) == (numFrames-1)
							Uxy(end, :) = Uxy(end-1, :);
						else
							Uxy(idxErr(1:2:end), :) = (Uxy(idxErr(1:2:end)-1, :) + Uxy(idxErr(1:2:end)+1, :)) ./ 2;
						end
						Ut = diff(Uxy,[],1);
						% 					[~, Ut] = gradient(Uxy);
						idxErr = find( any(bsxfun(@gt, abs(Ut), errThresh*utErr),2));
						k=k-1;
					end
					
					% UPDATE ERROR RATE
					chunkRate = errCount/numFrames;
					Na = obj.CurrentFrameIdx;
					Nb = numFrames;
					N = Na+Nb;
					obj.ErrorRate = (Na/N)*errRate + (Nb/N)*chunkRate;
					
				end
			catch me
				msg = getReport(me);
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
			% 			ffStat = obj.FixedFrameStatCollector;
			% 			ccStat = obj.CorrCoeffStatCollector;
			
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
			% 			step(ccStat, reshape(Cuse, 1,1,numel(Cuse)));
			
			
		end
		function F = applyFrameShift(obj, F, Uxy)
			
			% CHECK INPUT
			[numRows, numCols, numFrames, numChannels] = size(F);
			
			
			% RETRIEVE (BACKGROUND) FRAME TO FILL EXTRAPOLATED AREAS ALONG EDGES
			Fbg = obj.FixedMean;
			
			% EXTRACT ROW-SHIFT & COL-SHIFT COMPONENTS OF INPUT  Uxy ->  [Uy , Ux]
			uy = reshape(Uxy(:,1), 1,1,numFrames,1);
			ux = reshape(Uxy(:,2), 1,1,numFrames,1);
			
			
			if obj.pUseGpu
				% ============================================================
				% CUSTOM BICUBIC INTERPOLATION KERNEL CONSTRUCTED USING ARRAYFUN
				% ============================================================
				F = resampleImageBicubicRunGpuKernel(F, uy, ux, Fbg);
				
				
			else
				% ============================================================
				% BUILT-IN INTERPOLATION FUNCTIONS
				%	(slower, restricted to linear & nearest on gpu)
				% ============================================================
				
				% GET SUBSCRIPTS & CONVERT INPUT IMAGE TO FLOATING-POINT
				dataisongpu = isa(F,'gpuArray');
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
				
				
				% PREPARE EXTRAPOLATION VALUE FOR IDENTIFYING LOST PIXELS
				% (can be set to any value more negative than most negative value in F)
				extrapVal = min( min(Ffp(:)), 0) - 1;
				
				% INTERPOLATE OVER NEW GRID SHIFTED BY Ux & Uy
				if numFrames > 1
					[Y,X,Z] = ndgrid(rowSubs, colSubs, frameSubs);
					Xq = bsxfun(@minus, X, ux);
					Yq = bsxfun(@minus, Y, uy);
					Zq = Z;
					Ffp = interpn( Y,X,Z, Ffp, Yq, Xq, Zq, 'linear', extrapVal);
				else
					try
						Ffp = interp2( Ffp, colSubs+ux, rowSubs+uy, 'linear', extrapVal);
					catch me
						getReport(me) % showError
					end
				end
				
				% REPLACE MISSING PIXELS ALONG EDGE	(identified using extrapVal)
				dMask = Ffp < 0;
				Ffp = Ffp + bsxfun(@times,...
					cast(Fbg, 'like', Ffp) - extrapVal,...
					cast(dMask,'like',Ffp)); %bitand more efficient?
				F = cast(Ffp,'like', F);
				
			end
			
		end
		function addStableUpdate2FixedFrameReference(obj, F)
			
			% 			ffStat = obj.FixedFrameStatCollector;
			% 			ccStat = obj.CorrCoeffStatCollector;
			
			% COMPUTE FRAME-CORRELATION COEFFICIENTS BETWEEN 'LOCALLY ALIGNED' FRAMES & FIXED-AVERAGE
			% 			if obj.UseWeightedFrameCorr
			% 				[Cuw, Cw] = findFrameCorrelationCoefficient(obj, F, obj.FixedMean);
			% 				C = Cw;
			% 				obj.FrameCorrelationUnweightedOutput = Cuw(:);
			% 				obj.FrameCorrelationWeightedOutput = Cw(:);
			% 			else
			% 			C = findFrameCorrelationCoefficient(obj, F, obj.FixedMean);
			
			C = findFrameCorrelationCoefficient(obj, F, obj.FixedReference);
			obj.FrameCorrelationUnweightedOutput = C(:);
			% 			end
			
			% UPDATE STABILITY THRESHOLD & DETERMINE STABLE FRAMES (RELATIVE TO GLOBAL AVERAGE)
			% 			globalCorrThresh = max(...
			% 				obj.GlobalCorrelationMinThreshold ,...
			% 				ccStat.Mean + ccStat.StandardDeviation.*ccStat.Skewness);%TODO: check
			globalCorrThresh = obj.GlobalCorrelationMinThreshold; % TODO
			kStable = bsxfun(@gt, C(:) , globalCorrThresh);
			
			% STORE CORRELATION-COEFFICIENTS & RESULTANT STABILITY ESTIMATE
			obj.StableFrameMostRecent = kStable;
			
			% ACCUMULATE STABLE FRAMES IN SEQUENTIAL MEAN (+ other statistics) & UPDATE LOCAL-FIXED-REFERENCE FRAME (current/recent)
			if any(kStable)
				fixedUpdate = F(:,:,kStable,:);
				obj.FixedReference = single( mean( fixedUpdate, 3));
				% 				obj.FixedReference = single(F(:,:,find(kStable,1,'last')));
				
			else
				% USE SINGLE MOST STABLE FRAME TO ADD PARTIAL UPDATE TO LOCAL & GLOBAL FIXED FRAMES
				[~, bestCorrIdx] = max(C(:));
				if ~isempty(bestCorrIdx)
					fixedUpdate = F(:,:,bestCorrIdx,:);
					a = single(1/8);
					obj.FixedReference = single(a.*single(fixedUpdate) + (1-a).*obj.FixedReference);
					% 					obj.FixedReference = single(.75*obj.FixedReference + .25*fixedUpdate;
				else
					fixedUpdate = F(:,:,end,:);
				end
			end
			
			% UPDATE FIXED-FRAME STATISTIC-ACCUMULATOR
			% 			step(ffStat, fixedUpdate);
			updateRunningStatistics(obj, fixedUpdate);
			
		end
		function updateRunningStatistics(obj, F)
			
			% 			fixedFrameStat = obj.FixedFrameStatCollector;
			
			% 			fM1 = obj.FixedMean;
			% 			fMin = obj.FixedMin;
			% 			fMax = obj.FixedMin;
			
			% FIXED MEAN
			a = max(single(.95), single(1-.005*size(F,3)));
			obj.FixedMean = a.*obj.FixedMean + (1-a).*single(mean(F,3));
			
			% FIXED MAX & MIN
			obj.FixedMax = max(obj.FixedMax, max(F,[],3));
			obj.FixedMin = min(obj.FixedMin, min(F,[],3));
			
			
		end
		function info = getCorrectionInfo(obj, Uxy)
			
			% MANAGE LAST BUFFERED ENTRY FOR CONTINUOUS (INTER-CHUNK) MOTION ESTIMATION
			Uxy0 = obj.UxyMostRecent;
			UxyBuf = cat(1, Uxy0, Uxy);
			obj.UxyMostRecent = Uxy(end,:);
			
			% BRING RESULTS TO CPU FOR SIMPLER INCLUSION IN STRUCTURED OUTPUT
			dUxy = onCpu(obj, bsxfun(@minus, Uxy , UxyBuf(1:end-1,:))); % Uxy(:,:,1:end-1))));
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
			subsCenteredOn = @(csub,n) (floor(csub-n/2):floor(csub+n/2-1))'; %(changed 10/13/2015)
			numRows = obj.FrameSize(1);
			numCols = obj.FrameSize(2);
			
			% CALCULATE WINDOW SIZE THAT OPTIMIZES FFT
			% 			subWinSize = min(obj.FrameSize(1:2));
			subWinSize = [numRows numCols];
			if obj.UseSmallSubWindow
				subWinSize = 2.^(nextpow2(subWinSize)-1);
			else
				subWinSize = 2.^(nextpow2(subWinSize));
			end
			while any(subWinSize > [numRows numCols])
				gtDim = double(subWinSize > [numRows numCols]);
				subWinSize = 2.^(nextpow2(subWinSize) - gtDim);
			end
			obj.SubWinCenterRow = floor(numRows/2) + 1;
			obj.SubWinCenterCol = floor(numCols/2) + 1;
			obj.SubWinSize = subWinSize;
			
			% STORE SUBSCRIPTS FOR SELECTION OF SUB-WINDOWS FOR ALIGNMENT
			obj.SubWinRowSubs = onGpu(obj, subsCenteredOn(obj.SubWinCenterRow, subWinSize(1)));
			obj.SubWinColSubs = onGpu(obj, subsCenteredOn(obj.SubWinCenterCol, subWinSize(end)));
			
			% CONSTRUCT WINDOWING FUNCTION/MASK TO REDUCE EDGE-EFFECTS OF FFT
			% 			obj.SubWinAntiEdgeWin = onGpu(obj, single(hann(subWinSize) * hann(subWinSize)'));
			obj.SubWinAntiEdgeWin = onGpu(obj, single(hann(subWinSize(1)) * hann(subWinSize(end))')); %TODO
			
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















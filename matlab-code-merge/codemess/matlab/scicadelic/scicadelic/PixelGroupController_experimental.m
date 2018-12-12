classdef (CaseInsensitiveProperties = true) PixelGroupController < scicadelic.SciCaDelicSystem
	% PixelGroupController
	
	
	
	
	
	
	% USER SETTINGS
	properties (Nontunable)
		MinPersistentSize = 24
		LayerDiminishCoefficient = .75 %.5
		PeakSharpeningPower = .25
		LabelLockMinCount = 255		
		MinExpectedDiameter = 3;
		MaxExpectedDiameter = 20;
		NumRegionalSamples = 4;
		MaxNumSeeds = 2048
	end
	properties (Nontunable, Logical)
		UseRandSurround = true
		StabilizePixelLayer = false
	end
	
	% PRIVATE VARIABLES
	properties (SetAccess = protected)%, Hidden)
		PixelLabel							% Q (pixel label)
		PixelLayer							% R (regionally-normalized intensity -> image layer)
		BorderDistance					% S (geodesic distance to nearest border/layer-transition)
		PeakDistance						% T
		ProposedPixelLabel
		LockedPixelLabel		
		PeakCount
		BorderCount
		PositivePeakProbability
		NegativePeakProbability
		BorderProbability
		ActivityProbability
		LabelCount
		SteadyCount
		InputSize
		RowSubs
		ColSubs
		FrameSubs
		NumPastLabels
		RegionalDiffThreshold
		RadiusSample
		LabelEncodingMatrix
		BufferedFrame
		SeedingThreshold = .75
		JoiningThreshold = .25
	end
	properties (SetAccess = protected)
		DifferentialFrameStat
		DifferentialLayerStat
		DifferentialGradientStat		
		PeakCountFilterFcn
	end
	
	
	
	
	
	
	
	
	% CONSTRUCTOR
	methods
		function obj = PixelGroupController(varargin)
			setProperties(obj,nargin,varargin{:});
			obj.CanUseInteractive = true;
			
			obj.DifferentialFrameStat = scicadelic.StatisticCollector('DifferentialMomentOutputPort',true);
			obj.DifferentialLayerStat = scicadelic.StatisticCollector('DifferentialMomentOutputPort',true);
			obj.DifferentialGradientStat = scicadelic.StatisticCollector('DifferentialMomentOutputPort',true);
		end
	end
	
	% BASIC INTERNAL SYSTEM METHODS
	methods (Access = protected)
		function setupImpl(obj, F)
			
			gdev = parallel.gpu.GPUDevice.current; %TODO: move to parent
			
			% INITIALIZE IN STANDARD WAY
			fillDefaults(obj)
			checkInput(obj, F);
			obj.TuningImageDataSet = [];
			setPrivateProps(obj)
			if ~isempty(obj.GpuRetrievedProps)
				pushGpuPropsBack(obj)
			end
			obj.NFrames = 0; %TODO (in parent class)
			
			% STORE UPDATABLE PIXEL SUBSCRIPTS INTO STACK/CHUNK OF FRAMES
			[numRows, numCols, ~] = size(F);
			numPixels = numRows*numCols;
			updateFrameChunkSubscripts(obj, F);
			obj.LabelEncodingMatrix = getLabelEncodingMatrix(obj);
			
			% INITIALIZE BUFFERED FRAME FOR TEMPORAL GRADIENTS -> FROM MEAN OF FIRST STACK
			obj.BufferedFrame = cast(mean(F,3), 'like', F);
							
			% INITIALIZE PIXEL LAYER (TISSUE CLASSIFICATION) INPUT PARAMETERS
			obj.RegionalDiffThreshold = max(fix(min(range(F,1),[],2) / 4), [], 3);
			radiusRange = onGpu(obj, (ceil(obj.MinExpectedDiameter/2)+1) .* [1 5]); % was [1 3], was MaxExpectedDiameter
			radiusRange(end) = max(radiusRange(end), 2*obj.MaxExpectedDiameter);
			numRegionalSamples = obj.NumRegionalSamples;
			maxNumSamples = radiusRange(end)-radiusRange(1)+1;
			if (maxNumSamples) > numRegionalSamples
				obj.RadiusSample = onGpu(obj, int32(reshape(linspace(radiusRange(1),...
					radiusRange(end), numRegionalSamples), 1,1,1,numRegionalSamples)));
			else
				obj.RadiusSample = onGpu(obj, int32(reshape(radiusRange(1):radiusRange(end), 1,1,1,maxNumSamples)));
			end
			
			% CONSTRUCT GAUSSIAN-FILTER FUNCTION FOR SMOOTHING PEAK-COUNT
			sigma = obj.MinExpectedDiameter/4;
			obj.PeakCountFilterFcn = constructLowPassFilter(obj, obj.FrameSize, sigma);
			
			% INITIALIZE PIXEL REGION SAMPLING & LAYER CLASSIFICATION OUTPUTS
			obj.BorderDistance = gpuArray.ones(numRows, numCols, 'single')*numPixels;
			obj.PeakCount = gpuArray.zeros(numRows, numCols,'int32');
			obj.BorderCount = gpuArray.zeros(numRows, numCols,'int32');
			obj.PositivePeakProbability = gpuArray.zeros(numRows, numCols, 'single');
			obj.NegativePeakProbability = gpuArray.zeros(numRows, numCols, 'single');
			obj.BorderProbability = gpuArray.zeros(numRows, numCols, 'single');
			
			% INITIALIZE LABEL DESCRIPTOR MATRICES
			obj.PixelLabel = gpuArray.zeros(numRows, numCols, 'uint32');
			obj.ProposedPixelLabel = gpuArray.zeros(numRows,numCols,'uint32');
			obj.LockedPixelLabel = gpuArray.zeros(numRows,numCols,'uint32');
			obj.LabelCount = gpuArray.zeros(numRows,numCols,'int32');
			obj.SteadyCount = gpuArray.zeros(numRows,numCols,'int32');
			
			% CALL FIRST COUPLE QUASI-ITERATIVE SURFACE CHARACTERIZATION STEPS TO ADEQUATELY INITIALIZE
			R = samplePixelRegion(obj, F);
			numInitIter = 32;
			for k=1:numInitIter
				classifyLayeredRegion(obj, R);
			end
			
			% RESET PEAK-COUNT & BORDER COUNT (INACCURATE DURING INITIAL ITERATIONS)
			wait(gdev)
			obj.PeakCount = gpuArray.zeros(numRows, numCols,'int32');
			obj.BorderCount = gpuArray.zeros(numRows, numCols,'int32');
			
			
			
			
		end
		function [labelGroupSignal, Q] = stepImpl(obj,F) % [labelGroupSignal, labelGroupIdx] = stepImpl(obj,F)
			
			[numRows, numCols, numFrames] = size(F);
			obj.NFrames = obj.NFrames + numFrames;
			
			% UPDATE ROW,COL,FRAME SUBSCRIPTS
			updateFrameChunkSubscripts(obj, F);
			
			% UPDATE FLUORESCENCE INTENSITY STATISTICS (W/ DIFFERENTIAL OUTPUT)
			dFrameStat = step(obj.DifferentialFrameStat, F);
			
			% GENERATE LAYER PROBABILITY MATRIX (R) [-1,1]
			R = samplePixelRegion(obj, F);
			dLayerStat = step(obj.DifferentialLayerStat, R);
			
			% CLASSIFY PEAKS & LAYER-BORDERS BY MEASURING PEAK-BORDER-DISTANCE (geodesic distance to zero-crossing)
			[S, sPeak, rBorder] = classifyLayeredRegion(obj, R);
			
			% INITIALIZE PIXEL LABELS WITH LOCKED-LABELS & LAYER INFO
			Qseed = initializePixelLabel(obj, R);
			
			
			
			
			
			
			% PROPAGATE PIXEL LABEL
			Q0 = obj.PixelLabel;
			Q = propagatePixelLabel(obj, Q0, R);
			
			% REFINE PIXEL LABEL
			Q = refinePixelLabel(obj, Q);
			
			% ACCUMULATE LABEL VALUES -> COUNT, MIN, MAX, & MEAN (19.04)
			[labelGroupSignal, labelGroupSize] = encodePixelGroupOutput(obj, F, Q);
			
			% UPDATE LABEL INCIDENCE (TODO)
			
			% STORE RESULTS TO BUFFER PROPERTIES
			bufferResults(obj, F, Q, Qlock)
						
			% TODO: ALLOW MULTIPLE OUTPUT-PORTS (e.g. pixelLayerUpdate, pixelLabelInitial...)
		end
		function resetImpl(obj)
			dStates = obj.getDiscreteState;
			fn = fields(dStates);
			for m = 1:numel(fn)
				dStates.(fn{m}) = 0;
			end
		end
		function releaseImpl(obj)
			release(obj.DifferentialFrameStat)
			release(obj.DifferentialLayerStat)
			release(obj.DifferentialGradientStat)
			fetchPropsFromGpu(obj)
		end
	end
	
	% RUN-TIME HELPER FUNCTIONS
	methods (Access = protected, Hidden)
		function updateFrameChunkSubscripts(obj, F)
			
			% UPDATE ROW,COL,FRAME SUBSCRIPTS
			[numRows, numCols, numFrames] = size(F);
			rowSubs = obj.RowSubs;
			colSubs = obj.ColSubs;
			frameSubs = obj.FrameSubs;
			if (numRows~=numel(rowSubs)) || (numCols~=numel(colSubs)) || (numFrames~=numel(frameSubs))
				rowSubs = int32(gpuArray.colon(1,numRows)');
				colSubs = int32(gpuArray.colon(1,numCols));
				frameSubs = int32(reshape(gpuArray.colon(1, numFrames), 1,1,numFrames));
				obj.RowSubs = rowSubs;
				obj.ColSubs = colSubs;
				obj.FrameSubs = frameSubs;
			end
			obj.InputSize = int32([numRows, numCols, numFrames]);
			
		end
		function varargout = samplePixelRegion(obj, F)
			
			% CALL EXTERNAL FUNCTION TO EXECUTE GPU KERNEL
			R = samplePixelRegionRunGpuKernel(F, obj.RegionalDiffThreshold, obj.RadiusSample, obj.UseRandSurround, obj.RowSubs, obj.ColSubs, obj.FrameSubs);
			% [R,Flut] = samplePixelRegionRunGpuKernel(F, obj.RegionalDiffThreshold, obj.RadiusSample, obj.UseRandSurround, obj.RowSubs, obj.ColSubs, obj.FrameSubs);
			
			% INTEGRATE UPDATE WITH TEMPORALLY-STABILIZED PIXEL LAYER (TODO)
			if obj.StabilizePixelLayer
				R0 = obj.PixelLayer;
				if ~isempty(R0)
					R = bsxfun(@plus, R0, R)./2;
					R = bsxfun(@max,...
						abs(R0)*obj.LayerDiminishCoefficient,...
						abs(R))...
						.* single(sign(R));
				end
			end
			
			% UPDATE STABLE LAYER
			obj.PixelLayer = mean(R,3);
			
			% OUTPUT
			if nargout
				varargout{1} = R;
			end
			
		end
		function varargout = classifyLayeredRegion(obj, R)
			% CLASSIFICATION OF PIXELS IN REGIONAL CONTEXT - (QUASI-ITERATIVE SURFACE CHARACTERIZATION)
			% This function refines the classification of current pixels using a nonlinear mix of current and historical information.
			% It also updates variables that store pixel history for future use (peak-incidence, transition-incidence, etc.)
			% It calls an external function that calculates "transition-distance" on the GPU, which runs a gpu-kernel that calculates historically informed shortest-path (geodesic distance?) to any pixel with dissimilar classification.
			
			% CREATE LOCAL VARIABLES
			peakCount = obj.PeakCount;
			borderCount = obj.BorderCount;
			S0 = obj.BorderDistance;
			N = obj.NFrames;
			Rmean = abs(mean(R,3));
			
			% CALL EXTERNAL FUNCTION TO  EXECUTE GPU KERNEL
			[S, sPeak, rBorder] = classifyLayeredRegionRunGpuKernel(R, S0, single(obj.MinExpectedDiameter/2), obj.RowSubs, obj.ColSubs, obj.FrameSubs);
			
			% ACCUMULATE PEAK & BORDER COUNTS
			peakCount = peakCount + cast(sum(sPeak,3) ,'like',peakCount);
			borderCount = borderCount + cast(sum(rBorder, 3), 'like', borderCount);
			peakMax = max(abs(peakCount(:)));
			borderMax = max(abs(borderCount(:)));
			Pborder = Rmean .* obj.PeakCountFilterFcn(single(borderCount) ./ single(max(N, borderMax))); % single(max(N, max(borderMax, 256)));
			Ppeak = Rmean .* obj.PeakCountFilterFcn(single(peakCount) ./ single(max(N, peakMax)));
			Rmax = max(R,[],3);
			Rmin = min(R,[],3);
			
			% UPDATE BORDER-DISTANCE & POSITIVE/NEGATIVE PEAK PROBABILITY INTERNAL PROPERTIES
			obj.BorderDistance = mean(S,3); % min(S,[],3); %
			obj.PositivePeakProbability = max(Ppeak,0); %.* single(Rmin > 0);% new, switched Pmin/Pmix
			obj.NegativePeakProbability = max(-Ppeak,0); % .* single(Rmax < 0);
			obj.BorderProbability = Pborder;
			obj.PeakCount = peakCount;
			obj.BorderCount = borderCount;
			
			if nargout
				varargout{1} = S;
				if nargout > 1
					varargout{2} = sPeak;
					if nargout > 2
						varargout{3} = rBorder;
					end
				end
			end
			
		end
		function varargout = initializePixelLabel(obj, R)
			
			% GATHER CLASSIFICATION PROBABILITY MATRICES FROM INTERNAL STORAGE
			Ppeak = obj.PositivePeakProbability;
			
% 			maxNumPeaks = 
			
			Qproposed = obj.ProposedPixelLabel;			
			Qlocked = obj.LockedPixelLabel;
			numProposed = nnz(Qproposed);
			numLocked = nnz(Qlocked);
			num2MeetQuota = obj.MaxNumSeeds - (numProposed + numLocked);
			
			
			% CONSTRUCT HISTOGRAM OF PEAK-PROBABILITIES -> BROKEN DOWN INTO LABELED, UNLABELED, SEEDING, ETC.
			peakHistBins = linspace(.1, 1, 256);
			isPotentialPeak = Ppeak > peakHistBins(1);
			
			% 			numPotential = nnz(isPotentialPeak);			
			Ppotential = Ppeak(isPotentialPeak);
			peakHist = histc(Ppotential, peakHistBins);
			peakCDF = flipud(cumsum(flipud(peakHist)));
			if (num2MeetQuota >= 1) %numPotential > num2MeetQuota
				seedThresh = min(peakHistBins(peakCDF<=num2MeetQuota));
			else
				seedThresh = 1;
			end
			
			% CALL EXTERNAL FUNCTION TO EXECUTE GPU KERNEL
			% 			Q = obj.PixelLabel;
			% 			Qlock = obj.LockedPixelLabel;
			% 			Q0 = initializePixelLabelRunGpuKernel(R, Q, Qlock, obj.RowSubs, obj.ColSubs);
			
			
			% 			obj.SeedingThreshold = seedThresh;
			% OUTPUT
			if nargout
				Qseed = obj.LabelEncodingMatrix .* uint32(Ppeak>seedThresh);
				varargout{1} = Qseed;
			end
			
		end
		function Q = propagatePixelLabel(obj, Q0, R)
			
			[Q, Rbest, Sbest, isSteady] = propagatePixelLabelRestrictedRunGpuKernel(Q0, R,...
				single(obj.SeedingThreshold), single(obj.JoiningThreshold), single(obj.MaxExpectedDiameter)/2,...
				obj.RowSubs, obj.ColSubs, obj.FrameSubs);
			
			% 			if obj.NFrames <
			Qk = Q0;
			for k=obj.FrameSubs
				[Qk, Rbest, Sbest, isSteady] = propagatePixelLabelRestrictedRunGpuKernel(Qk, R(:,:,k),...
					single(obj.SeedingThreshold), single(obj.JoiningThreshold), single(obj.MaxExpectedDiameter)/2,...
					obj.RowSubs, obj.ColSubs, 1);
				Q(:,:,k) = Qk;
			end
			% 			obj.PixelLabel = pixelLabel;
			obj.SteadyCount = obj.SteadyCount + cast(sum(isSteady,3), 'like', obj.SteadyCount);
			
		end
		function pixelLabel = refinePixelLabel(obj, pixelLabel)
			
			N = obj.NFrames;
			% 			[numRows, numCols, ~] = size(pixelLabel);
			
			% TODO: reconsider using historical steadyProbability measure (will dampen ability to move labels with motion of image)
			
			if (N > 255)
				% CREATE LOCAL VARIABLES
				% 				peakIncidence = obj.PeakCount;
				% 				transitionIncidence = obj.BorderCount;
				steadyIncidence = obj.SteadyCount;
				
				% (?? unused)
				% 				peakProbability = single(peakIncidence) ./ N;
				% 				transitionProbability = single(transitionIncidence) ./ N;
				
				% (causing problems??????)
				steadyProbability = (single(steadyIncidence)./N).^2;
				% 				fairlySteadyPixel = steadyProbability > 0.5;
				% 				pixelLabel = bsxfun(@times, pixelLabel, cast(fairlySteadyPixel, 'like', pixelLabel));
				
				% ( ?? unused, maybe faster)
				% 				pixelLabel = bsxfun(@bitand, pixelLabel, cast(fairlySteadyPixel, 'like', pixelLabel).*intmax(classUnderlying(pixelLabel)));
				% 				unsteadyLabel = (1 - steadyProbability) > .5; %TODO
				% 				unsteadyLabel = erf(pi*(1 - steadyProbability)) > .5; %TODO
				% 				pixelLabel = bsxfun(@times, pixelLabel, cast(~unsteadyLabel, 'like', pixelLabel));
				
				% LOCK VERY STEADY PIXEL-LABELS (TODO: move back to a gpu-kernel function)
				generallySteadyPixel = steadyProbability > 0.95; %TODO, ... 0.75?
				currentlySteadyPixel = all(bsxfun(@eq, pixelLabel(:,:,1), pixelLabel), 3);
				lockablePixel = currentlySteadyPixel & generallySteadyPixel;
				obj.LockedPixelLabel = bsxfun(@times, pixelLabel(:,:,1), cast(lockablePixel, 'like', pixelLabel));
				% 				bsxfun(@bitand, pixelLabel(:,:,1), cast(lockablePixel, 'like', pixelLabel).*intmax(classUnderlying(pixelLabel)))
				
				% 				px1 = pixelLabel(:,:,1);
				% 				obj.LockedPixelLabel(lockablePixel) = px1(lockablePixel);
				
			end
			
			
			
			% TODO
			
			
		end
		function [labelGroupSignal, varargout] = encodePixelGroupOutput(obj, F, pixelLabel)
			% 			[labelGroupSignal, labelGroupIdx, varargout] = encodePixelGroupOutput(obj, F, pixelLabel)
			
			[numRows, numCols, numFrames] = size(F);
			numPixels = numRows*numCols;
			outputSize = [numPixels, numFrames];
			
			labelMask = logical(pixelLabel);
			frameInChunk = bsxfun(@times, uint16(labelMask), obj.FrameSubs);
			labelRow = bitand( pixelLabel , uint32(65535));
			labelCol = bitand( bitshift(pixelLabel, -16), uint32(65535));
			labelIdx = labelRow(:) + numRows*(labelCol(:)-1);
			
			% APPLY MASK TO LABEL INDICES - ALL LABEL INDICES FOR EACH FRAME ARE IN A SINGLE ROW
			maskedIdxFramePair = [labelIdx(labelMask) , frameInChunk(labelMask)];
			maskedF = single(F(labelMask));
			
			labelSize = accumarray(maskedIdxFramePair,...
				1, outputSize, @sum, 0, false);
			labelSum = accumarray(maskedIdxFramePair,...
				maskedF, outputSize, @sum, single(0), false);
			labelMax = accumarray(maskedIdxFramePair,...
				maskedF, outputSize, @max, single(0), false);
			labelMin = accumarray(maskedIdxFramePair,...
				maskedF, outputSize, @min, single(0), false);
			
			labelMaskConfirmed = (labelSum>0); %?? TODO
			
			[lsRow, lsCol] = find(labelMaskConfirmed);
			groupSignalMix = [...
				uint16(labelSize(labelMaskConfirmed)) ,...
				uint16(labelSum(labelMaskConfirmed)./labelSize(labelMaskConfirmed)) ,...
				uint16(labelMax(labelMaskConfirmed)) ,...
				uint16(labelMin(labelMaskConfirmed)) ]';
			groupSignalMixTypeCasted = typecast(groupSignalMix(:), 'double');
			
			labelGroupSignal = accumarray([lsRow, lsCol], groupSignalMixTypeCasted, outputSize, [],  0, true);
			% 			labelGroupIdx = labelIdx(labelMaskConfirmed);
			% 			szL = uint16(labelSize);
			
			if nargout > 1 % 2
				varargout{1} = uint16(labelSize);
			end
			
		end
		function bufferResults(obj, F, Q, Qlock)
			
			% CALL SEARCHING FUNCTION THAT FINDS THAT LAST LABEL FOR EACH PIXEL
			Q0 = reduceToLastLabelRunGpuKernel(Q, Qlock, obj.RowSubs, obj.ColSubs);
			
			% SAVE MATRICES TO PRIVATE PROPERTIES FOR INITIALIZATION OF NEXT ROUND
			obj.BufferedFrame = F(:,:,end);
			obj.LockedPixelLabel = Qlock;
			obj.PixelLabel = Q0;
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
	methods
		function Qpack = getLabelEncodingMatrix(obj)
			colSubs = single(obj.ColSubs);
			rowSubs = single(obj.RowSubs);
			if ~isempty(colSubs) && ~isempty(rowSubs)
				[Qcol, Qrow] = meshgrid(colSubs, rowSubs);
				Qpack = bitor(uint32(Qrow(:)) , bitshift(uint32(Qcol(:)), 16));
				Qpack = reshape(Qpack, numel(rowSubs), numel(colSubs));
			end
		end
	end
	
	
	
	
	
end














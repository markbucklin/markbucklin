classdef (CaseInsensitiveProperties = true) PixelLabel < hgsetget
	
	
	
	
	
	
	% SETTINGS
	properties (Constant)
		MaxNumRegisteredRegions = 4096
		DetectionStartDelay = 64				% Delay before measuring/accumulating input region properties
		RegistrationStartDelay = 128		% Delay before declaring/assigning tracked regions
		MinRegionArea = 12
		TargetRegionDiameter = 12
		MaxRegionDiameter = 64
		MinBorderDist = 16							% Suppress regions within MinBorderDist pixels from edge of image
		MaxNumPixelAssignment = 4
	end
	properties
		RegionPotentialInputThresh = .1
		RegionSuppressionEdgeThresh = .65
	end
	
	% LISTS
	properties (SetAccess = ?rtsci.System)
		RegionArea
		RegionBoundingBox
		RegionCentroid
		RegionFrequency
		RegionSeedIdx
		RegionSeedSubs
	end
	properties (SetAccess = ?rtsci.System)
		LocalPixelPMI
		LocalPixelProbability
		LocalPixelJointProbability
		LocalPixelComputeCount
	end
	properties (SetAccess = ?rtsci.System, Hidden)
		RegionMeanArea
		RegionMeanBoundingBox
		RegionMeanCentroid
		RegionAreaStDev
		RegionBoundingBoxStDev
		RegionCentroidStDev
	end
	
	% MAPS
	properties (SetAccess = ?rtsci.System)
		RegisteredRegionSeedIdxMap
		PrimaryRegionIdxMap
		SecondaryRegionIdxMap
		SecondaryRegionProbability
	end
	properties
		IsFilled
		IsPrimary
	end
	properties (SetAccess = ?rtsci.System)
		Pcell
		Pvessel
		Pneuropil
	end
	properties (SetAccess = ?rtsci.System)
		Pedge
		Pcenter
	end
	
	% OTHER PROPERTIES
	properties (SetAccess = ?rtsci.System)
		NumRegisteredRegions
		N
		IsDetectionStarted = false
		IsRegistrationStarted = false
		IsRegistryInitialized = false
	end
	
	% INTERNAL
	properties (SetAccess = ?rtsci.System)
		PotentialRegionCount
		CondensedRegionCount % DetectedRegionCount
		DilatedRegionCount
		DetectedRegionCount
		OuterEdgeCount
		InnerEdgeCount
		RegionSeedProbability
		PotentialSeedCount
		RegisteredRegionCount
	end
	properties (SetAccess = ?rtsci.System)
		PotentialRegionBuffer
		CondensedRegionBuffer
		DilatedRegionBuffer
		DetectedRegionBuffer % RegisteredRegionBuffer
		OuterEdgeBuffer
		InnerEdgeBuffer
		PotentialSeedBuffer
	end
	properties (SetAccess = ?rtsci.System)
		SpatialContinuityLut
		TemporalContinuityLut
		EdgeContinuityLut
	end
	properties (SetAccess = ?rtsci.System)
		DetectedRegionPixelStatistics
	end
	properties (Hidden)
		PreviousStateCopy
	end
	
	
	
	
	
	
	
	
	
	
	events
		RegionDetectionStarted
		RegionRegistrationStarted
		NewRegionRegistered
	end
	
	
	
	
	
	
	
	methods
		function obj = PixelLabel(varargin)
		end
		function initialize(obj, Q)
			% INITIALIZE REGISTRY
			
			% LOCAL VARIABLES
			[numRows,numCols,~,~] = size(Q);
			numSeeds = obj.MaxNumRegisteredRegions;
			numSecondary = obj.MaxNumPixelAssignment;
			
			% BACKUP OF CURRENT STATE IF NOT DEFAULT-EMPTY
			if ~isempty(obj.RegionSeedIdx)
				obj.PreviousStateCopy = oncpu(struct(obj));
			end
			
			% INDEXED/REGISTERED REGION DESCRIPTORS
			obj.RegionSeedSubs = int32(zeros(numSeeds,2,'like',Q)); % [row,col]
			obj.RegionSeedIdx = int32(zeros(numSeeds,1,'like',Q)); % [row,col]
			obj.RegionArea = single(zeros(numSeeds,1,'like',Q));
			obj.RegionBoundingBox = single(zeros(numSeeds,4,'like',Q));
			obj.RegionCentroid = single(zeros(numSeeds,2,'like',Q));
			obj.RegionFrequency = single(zeros(numSeeds,1,'like',Q));
			
			% PIXEL-TO-INDEX MAPS
			obj.RegisteredRegionSeedIdxMap = single(zeros(numRows,numCols,1, 'like',Q));
			obj.PrimaryRegionIdxMap = single(zeros(numRows,numCols,1, 'like',Q));
			obj.SecondaryRegionIdxMap = single(zeros(numRows,numCols,numSecondary, 'like',Q));
			obj.SecondaryRegionProbability = single(zeros(numRows,numCols,numSecondary, 'like',Q));
			
			% REGIONAL POINTWISE MUTUAL INFORMATION
			dMax = obj.MaxRegionDiameter;
			obj.LocalPixelPMI = single(zeros(dMax,dMax,numSeeds, 'like',Q));
			obj.LocalPixelProbability = single(zeros(dMax,dMax,numSeeds, 'like',Q));
			obj.LocalPixelJointProbability = single(zeros(dMax,dMax,numSeeds, 'like',Q));
			obj.LocalPixelComputeCount = single(0);
			
			% PIXEL-FEATURE PROBABILITY MAPS
			obj.Pcell = single(zeros(numRows,numCols,1,'like',Q));
			obj.Pvessel = single(zeros(numRows,numCols,1,'like',Q));
			obj.Pneuropil = single(zeros(numRows,numCols,1,'like',Q));
			obj.Pedge = single(zeros(numRows,numCols,1,'like',Q));
			obj.Pcenter = single(zeros(numRows,numCols,1,'like',Q));
			
			% PIXEL-FEATURE DECISION
			obj.IsFilled = false(numSeeds,1,'like',logical(Q));
			obj.IsPrimary = false(numSeeds,1,'like',logical(Q));
			
			% THRESHOLDED FEATURE COUNTS
			obj.PotentialRegionCount = single(zeros(numRows,numCols,1,'like',Q));
			obj.CondensedRegionCount = single(zeros(numRows,numCols,1,'like',Q));
			obj.DilatedRegionCount = single(zeros(numRows,numCols,1,'like',Q));
			obj.DetectedRegionCount = single(zeros(numRows,numCols,1,'like',Q));
			obj.OuterEdgeCount = single(zeros(numRows,numCols,1,'like',Q));
			obj.InnerEdgeCount = single(zeros(numRows,numCols,1,'like',Q));
			obj.PotentialSeedCount = single(zeros(numRows,numCols,1,'like',Q));
			obj.RegionSeedProbability = single(zeros(numRows,numCols,1,'like',Q));
			obj.RegisteredRegionCount = single(zeros(numSeeds,1,'like',Q));
			
			% THRESHOLDED FEATURE BUFFERS
			obj.PotentialRegionBuffer = false(numRows,numCols,1,'like',logical(Q));
			obj.CondensedRegionBuffer = false(numRows,numCols,1,'like',logical(Q));
			obj.DilatedRegionBuffer = false(numRows,numCols,1,'like',logical(Q));
			obj.DetectedRegionBuffer = false(numRows,numCols,1,'like',logical(Q));
			obj.OuterEdgeBuffer = false(numRows,numCols,1,'like',logical(Q));
			obj.InnerEdgeBuffer = false(numRows,numCols,1,'like',logical(Q));
			obj.PotentialSeedBuffer = false(numRows,numCols,1,'like',logical(Q));
			
			% INDEX AND MAPPED PIXEL COUNTS
			obj.NumRegisteredRegions = 0;
			obj.N = 0;
			
			% TUNE Q-THRESHOLD (TODO)
			if isempty(obj.RegionPotentialInputThresh)
				obj.RegionPotentialInputThresh = zeros(1,1,'like',Q) + .1;
			else
				obj.RegionPotentialInputThresh = bsxfun(@plus, zeros(1,1,'like',Q), double(obj.RegionPotentialInputThresh));
			end
			
			% CONSTRUCT TEMPORAL LUT
			tlutfcn = @(x)...
				(min(sum(x,2)) >= 1) ...
				| (sum(x(2,:)) > 2) ...
				| ((sum(x(2,:)) > 1) & (max(sum(x([1 3],:),2)) > 1));
			tlut = makelut(tlutfcn,3);
			obj.TemporalContinuityLut = false(512,1,'like',logical(Q)) | tlut;
			
			% CONSTRUCT SPATIAL LUT
			slutfcn = @(x) ...
				(max(sum(x,1)) + max(sum(x,2)) >= 5) ...
				| ((min(sum(x,1)) + min(sum(x,2))) > 3) ;
			slut1 = false(512,1,'like',logical(Q)) | makelut(slutfcn,3);
			slut2 = false(512,1,'like',logical(Q)) | rtsci.internal.lutmajority;
			obj.SpatialContinuityLut = {slut1, slut2};
			
			% CONSTRUCT EDGE LUT (INNER & OUTER COMBINED)
			elut1 = false(512,1,'like',logical(Q)) | rtsci.internal.lutper4;
			elut2 = false(512,1,'like',logical(Q)) | rtsci.internal.lutfatten;
			obj.EdgeContinuityLut = {elut1, elut2};
			
			
		end
		function update(obj, Q)
			% Update: Input, Q, is a normalized [0,1] image
			
			% ----------------------------------------------------
			% INITIALIZATION/SETUP/CHECK-INPUT
			% ----------------------------------------------------
			if isempty(obj.RegionSeedSubs)
				
				% INITIALIZE IF THIS IS THE FIRST CALL
				initialize(obj, Q)
			end
			
			% GET SIZE OF INPUT
			[numRows,numCols,numFrames,~] = size(Q);
			numPixels = numRows*numCols;
			N0 = single(obj.N);
			Nk = obj.N + numFrames;
			
			% DELAY IF SPECIFIED
			if Nk <= obj.DetectionStartDelay
				obj.N = Nk;
				return
			elseif N0 <= obj.DetectionStartDelay
				qidx = (N0 + (1:numFrames)) > obj.DetectionStartDelay;
				Q = Q(:,:,qidx,:);
				N0 = N0 - 1 + find(qidx,1,'first');
				[numRows,numCols,numFrames,~] = size(Q);
			end
			if ~obj.IsDetectionStarted
				obj.IsDetectionStarted = true;
				notify(obj, 'RegionDetectionStarted')
			end
			
			
			
			% ----------------------------------------------------
			% IDENTIFY ACTIVATED REGIONS IN INPUT
			% ----------------------------------------------------
			% THRESHOLD INPUT
			R = applyInputThreshold(obj, Q);
			
			% DETECT REGIONS -> CONDENSE WITH LUT/MORPHOPS
			R = detectPixelRegions(obj, R);
			
			
			
			% ----------------------------------------------------
			% COMPUTE/UPDATE PROPERTIES OF IDENTIFIED REGIONS
			% ----------------------------------------------------
			if any(R(:))
				
				% REGION EDGE/BORDER-DEFINITION
				updateDetectedRegionEdgeMap(obj, R, Q)
				
				% LABEL DETECTED REGIONS & GET BASIC PROPERTIES
				Sdet = getDetectedRegionProps(obj, R, N0+1);
				assignin('base','Sdet',Sdet)
				
				% UPDATE DETECTED-REGION NORMALIZED PIXELWISE STATISTICS
				if ~isempty(Sdet.Area)
					statMap = updateDetectedRegionPropertyStatMap(obj, Sdet);
					assignin('base','statMap',statMap)
					
					% UPDATE DETECTED REGION SEED LOCALIZER
					Pseed = statMap.SeedProbability;
					bwSeed = updateDetectedRegionSeedLoc(obj, Pseed);
					assignin('base','bwSeed',bwSeed)
					
					
					% ----------------------------------------------------
					% APPLY UPDATES TO LABELS USING CURRENT SEEDS -> MAP SEEDS TO CURRENT LABELS
					% ----------------------------------------------------
					numSeeds = nnz(bwSeed);
					if (Nk > obj.RegistrationStartDelay) && (numSeeds >= 1)
						if ~obj.IsRegistrationStarted
							
							% INITIALIZE
							initializeRegionRegistry(obj, Sdet, statMap, bwSeed);
							
							% NOTIFY REGISTRATION STARTED
							obj.IsRegistrationStarted = true;
							notify(obj, 'RegionRegistrationStarted')
						end
						
						% UPDATE REGISTRY USING NEWLY DETECTED REGIONS (GENERATING PRIOR PROBABILITY MAPS)
						seedMap = updateRegionRegistry(obj, Sdet, statMap, bwSeed);
						
						
						% 						winSim = updateFixedWindowSeedPixelSimilarity(obj, Q, seedMap);
						
					end
					
				end
			end
			
			obj.N = Nk;
						
		end				
	end	
	% IDENTIFY ACTIVATED REGIONS IN INPUT
	methods
		function R = applyInputThreshold(obj, Q)
			
			% TODO: USE MARKOV-STATES
			%			-> VARIABLE POTENTIATION FOR EACH CHANNEL
			%			-> SHIFT THRESHOLDS
			%			-> DEVIATE RESULTANT TYPE/FLAVOR/STATE OF REGION (i.e. static vs. dynamic,... active... edge)
			R = bsxfun(@ge, Q, obj.RegionPotentialInputThresh);
			obj.PotentialRegionCount = obj.PotentialRegionCount + single(sum(R,3));
			
		end
		function R = detectPixelRegions(obj, R)
			
			% TEMPORAL CONTINUITY LOOKUP-TABLE (DILATION)
			R = applySlicedTemporalLut( R, obj.TemporalContinuityLut);
			
			% SPATIAL CONTINUITY LOOKUP TABLE
			R = applySpatialLut( R, obj.SpatialContinuityLut);
			
			% REGION POTENTIAL SUPPRESSION USING BORDERS & EDGE HISTORY
			if isa(R,'gpuArray')
				R = supressRegionPotentialRunGpuKernel( R, obj.MinBorderDist, [], []);
				% 				R = supressRegionPotentialRunGpuKernel( R, obj.MinBorderDist, obj.Pedge, obj.RegionSuppressionEdgeThresh);
			else
				R = bsxfun(@and, R, obj.Pedge<obj.RegionSuppressionEdgeThresh);
				rowVec = true( 1, size(R,2), 'like',R);
				rowVec(1:obj.MinBorderDist) = false;
				rowVec = rowVec & fliplr(rowVec);
				colVec = true( size(R,1), 1, 'like',R);
				colVec(1:obj.MinBorderDist) = false;
				colVec = colVec & flipud(colVec);
				R = bsxfun(@and, bsxfun(@and, R, rowVec), colVec);
			end
			
			% COUNTS & BUFFER
			obj.CondensedRegionCount = obj.CondensedRegionCount + single(sum(R,3));
			obj.DetectedRegionBuffer = R(:,:,end,:);
			
			
			
		end
	end
	% COMPUTE/UPDATE PROPERTIES OF IDENTIFIED REGIONS
	methods
		function updateDetectedRegionEdgeMap(obj, R, Q)
			
			% VARIABLE INPUT
			if nargin < 3
				Q = [];
			end
			
			% USE LOOKUP-TABLE OP TO FIND ROUGH BORDERS OF ACTIVATED REGIONS
			Reio = applySpatialLut(R, obj.EdgeContinuityLut);
			Rei = Reio & R; % Rei = bwmorphn(R,{'remove'});
			Reo = Reio & ~R; % Reo = bwmorphn(Rd,{'remove'});
			Rd = Reio | R; % applySpatialLut(R,rtsci.internal.lutdilate)
			
			% UPDATE EDGE/REGION COUNTS
			obj.InnerEdgeCount = obj.InnerEdgeCount + single(sum(Rei,3));
			obj.OuterEdgeCount = obj.OuterEdgeCount + single(sum(Reo,3));
			obj.DilatedRegionCount = obj.DilatedRegionCount + single(sum(Rd,3));
			
			% TODO: USE Q WITH POINTWISE-MI-KERNEL AND/OR STRUCTURETENSOREIGDECOMP -> STATIC EDGES
			
			% EDGE PROBABILITY (MOVE TO GET) (### REMOVEABLE ###)
			compensatedEdgeCount = (obj.OuterEdgeCount + obj.InnerEdgeCount)...
				- (obj.PotentialRegionCount + obj.CondensedRegionCount);
			obj.Pedge = max(0,compensatedEdgeCount)./max(1,obj.DilatedRegionCount);
			
			
		end
		function S = getDetectedRegionProps(obj, R, kIdx1)
			
			% VARIABLE INPUT
			if nargin < 3
				kIdx1 = [];
			end
			minArea = obj.MinRegionArea;
			[numRows, numCols, ~] = size(R);
			
			% NEW LABEL IDX-MAP - LABELMATRIX FOR MAPPING ACROSS CURRENT CHUNK
			[labelMat2d, numLabels] = bwlabel(reshape( R, numRows,[],1),4);
			labelListUnique = (1:numLabels)';
			
			% REMOVE UNDERSIZE LABELS
			labelList = nonzeros(labelMat2d); % replaced above two lines
			labelArea = accumarray(labelList(:), 1, [numLabels,1], @sum);
			isOverMinArea = labelArea >= minArea;
			overMinIdx = labelListUnique(isOverMinArea);
			
			% RE-MAP TO ORDERED/INDEXED SET OF OVER-MIN LABELS ONLY
			validAreaLabelLut = zeros(65536,1,'uint16');
			numLabels = single(numel(overMinIdx));
			labelListUnique = (1:numLabels)';
			validAreaLabelLut(overMinIdx+1) = labelListUnique;
			if isa(labelMat2d, 'gpuArray')
				labelMat2d = rtsci.internal.gpu.intlut(uint16(labelMat2d), validAreaLabelLut); % variable type change
			else
				labelMat2d = intlut(uint16(labelMat2d), validAreaLabelLut);
			end
			
			if isa(labelMat2d, 'gpuArray')
				% CALL EXTERNAL FUNCTION THAT USES GPU\ARRAYFUN
				S = getLabeledRegionPropsRunGpuKernel(labelMat2d, kIdx1, numCols);
				
			else
				% GATHER OTHER REGION PROPERTIES
				[labelRow,labelCol,labelIdx] = find(labelMat2d);
				labelFrameIdx = ceil(labelCol./single(numCols)); % TODO
				labelCol = rem(labelCol-1,numCols)+1;
				
				% COMPUTE REGION PROPERTIES FOR EACH LABEL (AREA, BOUDING-BOX, CENTROID)
				if ~isempty(labelIdx)
					y1 = accumarray(labelIdx, labelRow, [numLabels,1], @min);
					y2 = accumarray(labelIdx, labelRow, [numLabels,1], @max);
					x1 = accumarray(labelIdx, labelCol, [numLabels,1], @min);
					x2 = accumarray(labelIdx, labelCol, [numLabels,1], @max);
					cy = accumarray(labelIdx, labelRow, [numLabels,1], @sum);
					cx = accumarray(labelIdx, labelCol, [numLabels,1], @sum);
					k =  accumarray(labelIdx, labelFrameIdx, [numLabels,1], @max);
					a = labelArea(overMinIdx(:));
					
					cy = cy./a;
					cx = cx./a;
					
					seedRowSubs = round(cy);
					seedColSubs = round(cx);
					seedIdx = (seedColSubs-1).*numRows + seedRowSubs;
					
					% ASSIGN REGION PROPERTIES IN OUTPUT STRUCTURE
					S.Area = a;
					S.BoundingBox = [x1, y1, x2-x1, y2-y1];
					S.Centroid = [cx cy];
					S.FrameIdx = k(:);
					S.RegionSeedSubs = int32([seedRowSubs seedColSubs]);
					S.RegionSeedIdx = int32(seedIdx);
					
				else
					S.Area = [];
					S.BoundingBox = [];
					S.Centroid = [];
					S.FrameIdx = [];
					S.RegionSeedIdx = [];
					S.RegionSeedSubs = [];
					
				end
				% RESHAPE LABEL MATRIX TO 3D (CHUNK)
				S.LabelMatrix = reshape( uint16(labelMat2d) , numRows,numCols,[]);
			end
			
			
		end
		function statMap = updateDetectedRegionPropertyStatMap(obj, S)
			
			% GET COMPLEX PIXEL-WISE STATISTICS GIVEN CURRENT/NEW REGION PROPERTIES
			% 			stat = labeledRegionStatisticUpdateRunGpuKernel(S, obj.DetectedRegionPixelStatistics);
			
			% GET COMPLEX PIXEL-WISE TEMPORAL-FILTERED STATISTIC GIVEN CURRENT/NEW REGION PROPERTIES
			statMap = labeledRegionPropFilteredUpdateRunGpuKernel(S, obj.DetectedRegionPixelStatistics, single(.95));
			if ~isempty(statMap)
				obj.DetectedRegionPixelStatistics = statMap;
				obj.RegionSeedProbability = statMap.SeedProbability;
			end
			
		end
		function bwSeed = updateDetectedRegionSeedLoc(obj, Pseed)
			
			if nargin < 2
				Pseed = [];
			end						
			
			if isempty(Pseed)
				% GET LABELED REGION STATISTICS
				stat = obj.DetectedRegionPixelStatistics;
				if ~isempty(stat)
					Pseed = stat.SeedProbability;
				else
					bwSeed = false;
					return
				end
			end
			
			% FIND LOCAL PEAKS OF THE "SEED-PROBABILITY" PROPERTY MAP (CENTRALITY OF DYNAMICALLY LABELED REGIONS)
			seedPeakRadius = ceil(sqrt(obj.MinRegionArea));
			bwSeed = findLocalPeaksRunGpuKernel( Pseed, seedPeakRadius, .1);
			% 			[bwSeed, seedMapUpdate] = findLocalPeakSpreadValueRunGpuKernel( Pseed, seedMap, seedPeakRadius, .4, .65);
			
			% UPDATE POTENTIAL SEED COUNT
			obj.PotentialSeedCount = obj.PotentialSeedCount + single(bwSeed);
			
		end
	end	
	% APPLY UPDATES TO LABELS USING CURRENT SEEDS (POST REGISTRATION START DELAY)
	methods
		function initializeRegionRegistry(obj, Sdet, statMap, bwSeed)
			
			% INITIALIZE OPTIONAL INPUTS
			if nargin < 3
				bwSeed = [];
				if nargin < 2
					statMap = [];
				end
			end
			
			% GET EMPTY INPUTS FROM STORED PROPERTIES
			if isempty(bwSeed)
				seedPeakRadius = ceil(sqrt(obj.MinRegionArea));
				bwSeed = findLocalPeaksRunGpuKernel( obj.PotentialSeedCount, seedPeakRadius, .1);
			end
			if isempty(statMap)
				statMap = obj.DetectedRegionPixelStatistics;
			end
			
			% FILL REGISTERED-REGION SEED MAP			
			obj.NumRegisteredRegions = 0;
			% 			seedMapIdx = find(bwSeed(:));
			% 			% 			[seedRow, seedCol] = find(bwSeed);
			%
			% 			numSeeds = nnz(bwSeed);
			% 			regIdx = 1:numSeeds;
			% 			regIdx = regIdx(:);
			% 			% 			[numRows, numCols, ~] = size(bwSeed);
			% 			% 			seedMap = single(zeros(numRows,numCols,1, 'like',single(bwSeed)));
			% 			% 			seedMap(seedMapIdx) = regIdx;
			% 			% 			obj.RegisteredRegionSeedIdxMap = seedMap;
			%
			% 			% 			obj.PrimaryRegionIdxMap = seedMap;
			% 			% 			obj.NumRegisteredRegions = regCount;
			%
			%
			% 			% INITIALIZE REGION-PROPERTIES USING MEAN FROM PIXELWISE MAP
			% 			if ~isempty(statMap)
			%
			% 				% REGION AREA
			% 				meanArea = statMap.MeanArea(seedMapIdx);
			% 				obj.RegionArea(regIdx) = meanArea;
			%
			% 				% REGION BOUNDING-BOX
			% 				meanBoxCorner = statMap.MeanBBoxCorner(seedMapIdx);
			% 				meanBoxSize = statMap.MeanBBoxSize(seedMapIdx);
			% 				obj.RegionBoundingBox(regIdx,:) = ...
			% 					[ real(meanBoxCorner(:)) , imag(meanBoxCorner(:)) ,...
			% 					real(meanBoxSize(:)) , imag(meanBoxSize(:))];
			%
			% 				% REGION CENTROID
			% 				meanCentroid = statMap.MeanCentroid(seedMapIdx);
			% 				obj.RegionCentroid(regIdx,:) = [real(meanCentroid(:)) , imag(meanCentroid(:))];
			%
			% 				% REGION FREQUENCY
			% 				regionFreq = statMap.LabelCount(seedMapIdx) ./ max(statMap.FrameCount,1);
			% 				obj.RegionFrequency(regIdx) = regionFreq(:);
			%
			% 			end
			%
			% 			% SEED INDEX (ROW COLUMN SUBSCRIPTS TO SEED)
			% 			[seedRow, seedCol] = find(bwSeed);
			% 			obj.RegionSeedSubs(regIdx(:),:) = int32([seedRow(:) seedCol(:)]);
			
			% obj.RegionFrequency = obj.RegisteredRegionCount ./ max(1, obj.N-obj.RegistrationStartDelay);
			
			obj.IsRegistryInitialized = true;
			
		end		
				
		function seedMap = updateRegionRegistry(obj, Sdet, statMap, bwSeed)
			
			try
				
				% INITIALIZE OPTIONAL INPUTS
				if nargin < 4
					bwSeed = [];
					if nargin < 3
						statMap = [];
					end
				end
				
				% GET SEED PROBABILITY FROM UPDATED PIXELWISE STATISTIC MAP
				Pseed = statMap.SeedProbability;
				
				% CHECK INITIALIZATION STATE
				if ~obj.IsRegistryInitialized
					initializeRegionRegistry(obj, [], Pseed);
				end
				
				% GET EMPTY INPUTS FROM STORED PROPERTIES
				if isempty(Pseed)
					Pseed = obj.DetectedRegionPixelStatistics.SeedProbability;
				end
				if isempty(bwSeed)
					if ~isempty(Pseed)
						bwSeed = updateDetectedRegionSeedLoc(obj, Pseed);
					end
					if isempty(bwSeed) || (nnz(bwSeed)<1)
						return
					end
				end
			
				
				% INITIAL FILL OF REGION IDX MAP (LABEL MATRIX)		
			detMap = Sdet.LabelMatrix;
			reg1Map = obj.PrimaryRegionIdxMap;
			reg2Map = obj.SecondaryRegionIdxMap;
			
			[numRows, numCols, numFrames] = size(detMap);
			% 			detSeedMap = zeros(numRows,numCols,'like',Sdet.RegionSeedIdx);
			detSeedIdx = Sdet.RegionSeedIdx(:);
			bwDetSeed = bsxfun(@and, bwSeed, detMap);
			bwReg1Seed = bsxfun(@and, bwSeed, reg1Map);
			bwReg2Seed = bsxfun(@and, bwSeed, reg2Map);
			
			bwAnyDetSeed = any(bwDetSeed,3);
			bwAnyReg1Seed = any(bwReg1Seed,3);
			bwAnyReg2Seed = any(bwReg2Seed,3);
			
			bwNewRegSeed = bwAnyDetSeed & ~bwAnyReg1Seed & ~bwAnyReg2Seed;
			numNewSeeds = nnz(bwNewRegSeed);
			
			detIdx = detMap(bwDetSeed);
			reg1Idx = reg1Map(bwReg1Seed);
			reg2Idx = reg2Map(bwReg2Seed);
			
			numPotentialSeeds = nnz(bwSeed);
			numDetSeeds = nnz(bwAnyDetSeed);
			numReg1Seeds = nnz(bwAnyReg1Seed);
			numReg2Seeds = nnz(bwAnyReg2Seed);
			
			seedMap = uint16(zeros(numRows,numCols,1, 'like',uint16(bwSeed)));
			seedMap(bwAnyReg1Seed) = reg1Idx;
			seedMap(bwAnyReg2Seed) = reg2Idx;
			
			if (numNewSeeds >= 1)
				regCountCurrent = obj.NumRegisteredRegions;
				newRegIdx = regCountCurrent + (1:numNewSeeds);
				seedMap(bwNewRegSeed) = newRegIdx;
				obj.NumRegisteredRegions = regCountCurrent + numNewSeeds;
			end
				
			
			seedMapLinIdx = find(seedMap);
			[seedRow, seedCol, regIdx] = find(seedMap);
			obj.RegisteredRegionSeedIdxMap = seedMap;
			
			% 			regIdx = 1:numSeeds;
			% 			regIdx = regIdx(:);
			% 			[numRows, numCols, ~] = size(bwSeed);
			%
			% 			seedMap(seedMapIdx) = regIdx;
			% 			obj.RegisteredRegionSeedIdxMap = seedMap;
			%
			%
			%
			%
			% 			regIdx = find(detIdx);
			% 			detRegLut = zeros(65536,1, 'like',uint16(seedMapIdx));
			%
			% 			detRegLut(detIdx + 1) = regIdx;
			%
			%
			% 			bwDet = any(detMap,3);
			% 			numNewSeeds = nnz(bwSeed & anyDet) - nnz(seedMap & anyDet);
			% 			if numNewSeeds >= 1
			% 				regCountCurrent = obj.NumRegisteredRegions;
			% 				newRegIdx = regCountCurrent + (1:numNewSeeds);
			% 				obj.NumRegisteredRegions = regCountCurrent + numNewSeeds;
			% 				% 					seedMap lut
			% 			end
				
				
				
				% CONSTRUCT CURRENTLY 'REGISTERED' REGION PROP STRUCTURE & MAP
				% 				Sreg.Area = obj.RegionArea(regIdx);
				% 				Sreg.BoundingBox = obj.RegionBoundingBox(regIdx,:);
				% 				Sreg.Centroid = obj.RegionCentroid(regIdx,:);
				% 				Sreg.RegionSeedSubs = obj.RegionSeedSubs(regIdx,:);
				% 				Sreg.RegionSeedIdx = obj.RegionSeedIdx(regIdx,:);
				% 				Sreg.LabelMatrix = obj.PrimaryRegionIdxMap; % 2D-LUT
				% 				Sreg.SecondaryLabelMatrix = obj.SecondaryRegionIdxMap; % FLAG PIXEL IF PRIMARY TAKEN
				Sreg.Area = obj.RegionArea;
				Sreg.BoundingBox = obj.RegionBoundingBox;
				Sreg.Centroid = obj.RegionCentroid;
				Sreg.RegionSeedSubs = obj.RegionSeedSubs;
				Sreg.RegionSeedIdx = obj.RegionSeedIdx;
				Sreg.LabelMatrix = obj.PrimaryRegionIdxMap; % 2D-LUT
				Sreg.SecondaryLabelMatrix = obj.SecondaryRegionIdxMap; % FLAG PIXEL IF PRIMARY TAKEN
				
				
				
				% EXTERNAL FCN -> MAP DETECTED REGION INPUTS TO CURRENT REGISTERED REGIONS
				[S,M] = updateRegisteredRegionsRunGpuKernel(Sdet, Sreg, seedMap, Pseed);
				
				obj.RegionArea = S.Area;
				obj.RegionBoundingBox = S.BoundingBox;
				obj.RegionCentroid = S.Centroid;
				obj.RegionSeedSubs = S.RegionSeedSubs;
				obj.RegionSeedIdx = S.RegionSeedIdx;
				obj.PrimaryRegionIdxMap = S.LabelMatrix;
				
				% FIRE NEW REGION EVENT
				if numNewSeeds >= 1
					notify(obj, 'NewRegionRegistered');
				end
			
			catch me
				% CATCH ERRORS
				msg = getReport(me);
				disp(msg)
			end
			
			
			
			
		end
		
	end
	
	methods		
		function winSim = updateFixedWindowSeedPixelSimilarity(obj, Q, seedMap)			
			
			
			
			winSim = updateFixedWindowSeedPixelSimilarityRunGpuKernel(Q, seedMap, winSim);			
			
			
		end
	end
	
	
end














function bw = applySlicedTemporalLut(bw, tlut)
[nrow,ncol,nk] = size(bw);
npx = nrow*ncol;
vslice = reshape( bw, npx, nk);
hslice = reshape( permute(bw, [2 1 3 4]), npx, nk);
vslice = reshape( bwlookup( vslice, tlut), nrow, ncol, nk); %addchannels
hslice = reshape( bwlookup( hslice, tlut), ncol, nrow, nk); %addchannels
bw = vslice | permute(hslice, [2 1 3 4]);

end
function bw = applySpatialLut(bw, slut)
[nrow,ncol,nk] = size(bw);
bw2d = reshape( bw, nrow,[],1);
if isnumeric(slut)
	bw2d = bwlookup(bw2d, slut);
elseif iscell(slut)
	for kl = 1:numel(slut)
		bw2d = bwlookup(bw2d, slut{kl});
	end
end
bw = reshape( bw2d, nrow,ncol,nk); %addchannels

end










% MAP NEWLY-DETECTED REGIONS USING PROPS & LABELS IN S-DETECTED
% 				regMap = obj.PrimaryRegionIdxMap; % seedMap TODO: SecondaryRegionIdxMap
% 				detMap = Sdet.LabelMatrix;

% ADD NEW SEEDS TO REGION IDX MAP
% 				seedMap = obj.RegisteredRegionSeedIdxMap;%stop using??
% 				fatSeedMap = bwmorph(bwSeed, 'dilate');
% 				bwSeedOverlap = fatSeedMap & seedMap;
% 				% 				seedMap(bwSeedOverlap) = seedMap(bwSeedOverlap);
% 				% 				bwSeedNew = bwmorph((bwSeedFat & ~logical(seedMap)),'erode');
% 				% 				numNewSeeds = nnz(bwSeedNew);%
% 				% 				newOverlap = (overlapSeedIdx == 0);
% 				% 				seedMap(bwSeedOverlap) = overlapSeedIdx;
%
% 				numNewSeeds = nnz(bwSeedOverlap) - nnz(seedMap);%sum(newOverlap);
% 				if numNewSeeds >= 1 %any(newOverlap)
% 					regCountCurrent = obj.NumRegisteredRegions;
% 					newRegIdx = regCountCurrent + (1:numNewSeeds);
% 					seedMap(bwSeedOverlap) = newRegIdx;% not sure
% 					obj.RegisteredRegionSeedIdxMap = seedMap;
% 					obj.NumRegisteredRegions = regCountCurrent + numNewSeeds;
% 				end
%
% 				% 			cx =	uint16(real(statMap.MeanCentroid(bwSeed)));
% 				% 			cy =	uint16(imag(statMap.MeanCentroid(bwSeed)));

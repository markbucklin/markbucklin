classdef (CaseInsensitiveProperties = true) RoiGenerator < scicadelic.SciCaDelicSystem
	% RoiGenerator
	%
	% INPUT:
	%
	% OUTPUT:
	%	Array of objects of the 'RegionOfInterest' class, resembling a RegionProps structure (Former
	%	Output) Returns structure array, same size as vid, with fields
	%			bwvid =
	%				RegionProps: [12x1 struct] bwMask: [1024x1024 logical]
	%
	% INTERACTIVE NOTE: This system uses morphological operations from the following list, which can
	% be applied sequentially to a thresholded logical array of pixels identified as potentially
	% active:
	% 	     'bothat'       Subtract the input image from its closing
	%        'branchpoints' Find branch points of skeleton 'bridge'       Bridge previously
	%        unconnected pixels 'clean'        Remove isolated pixels (1's surrounded by 0's)
	%        'close'        Perform binary closure (dilation followed by
	%                         erosion)
	%        'diag'         Diagonal fill to eliminate 8-connectivity of
	%                         background
	%        'endpoints'    Find end points of skeleton 'fill'         Fill isolated interior pixels
	%        (0's surrounded by
	%                         1's)
	%        'hbreak'       Remove H-connected pixels 'majority'     Set a pixel to 1 if five or
	%        more pixels in its
	%                         3-by-3 neighborhood are 1's
	%        'open'         Perform binary opening (erosion followed by
	%                         dilation)
	%        'remove'       Set a pixel to 0 if its 4-connected neighbors
	%                         are all 1's, thus leaving only boundary pixels
	%        'shrink'       With N = Inf, shrink objects to points; shrink
	%                         objects with holes to connected rings
	%        'skel'         With N = Inf, remove pixels on the boundaries
	%                         of objects without allowing objects to break apart
	%        'spur'         Remove end points of lines without removing
	%                         small objects completely
	%        'thicken'      With N = Inf, thicken objects by adding pixels
	%                         to the exterior of objects without connected previously unconnected
	%                         objects
	%        'thin'         With N = Inf, remove pixels so that an object
	%                         without holes shrinks to a minimally connected stroke, and an object
	%                         with holes shrinks to a ring halfway between the hole and outer
	%                         boundary
	%        'tophat'       Subtract the opening from the input image
	%
	% See also: BWMORPH GPUARRAY/BWMORPH
	
	
	
	% USER SETTINGS
	properties (Access = public, Nontunable)
		OutputType = 'LabelMatrix'
		MaxExpectedDiameter = 50;					% Determines search space for determining foreground & activity		
		MorphOp1 = 'fill'
		MorphOp2 = 'close'
		MorphOp3 = 'clean'
		MorphOp4 = 'majority'
		MinRoiPixArea = 25;								% previously 50
		MaxRoiPixArea = 2500;							% previously 350, then 650, then 250				
	end
	properties (Access = public, Nontunable) % (not implemented)
		RecurrenceFilterNumFrames = 0;		% Number of prior frames to compare to current frame in foreground operation, any matches propagate
		PctActiveUpperLim= 4.5;						% .01 = 10K pixels (15-30 cells?)
		PctActiveLowerLim = .05;					% previous values: 500, 250
		MaxRoiEccentricity = .93;					% previously .92
		MaxPerimOverSqArea = 6;						% circle = 3.5449, square = 4 % Previousvalues: [6.5  ]
		MinPerimOverSqArea = 3.0;					% previously 3.5 PERIMETER / SQRT(AREA)		
	end
	
	% STATES
	properties (SetAccess = protected, Logical)
		OutputAvailable = false
	end
	properties (SetAccess = protected)
		CurrentFrameIdx
	end
	
	% OUTPUTS
	properties (SetAccess = protected)		
		LabelMatrix
		ConnComp
		Mask
		RegionProps
		SegmentationSum
	end
	properties (SetAccess = protected, Hidden)
		OutputTypeSet = matlab.system.StringSet({'LabelMatrix','ConnComp','Mask'})
		OutputTypeIdx
	end
	
	% BUFFERS
	properties (Nontunable, PositiveInteger)
		BufferSize								% Number of frames to buffer before running segmentation procedures
	end
	properties (SetAccess = protected, Hidden)		
		DataBuffer							% Circular buffer for holding frames passed to step; holding frames ready for segmentation		
		ForegroundBuffer					% Logical array representing unfiltered foreground pixels from all frames in Filled Buffer from pRecurrenceFilterNumFrames to end
	end
	
	% PRIVATE COPIES
	properties (SetAccess = protected, Hidden, Nontunable)
		pMaxExpectedDiameter
		pRecurrenceFilterNumFrames
		pMinRoiPixArea
		pMaxRoiPixArea
		pOutputType
	end
	
	% DYNAMIC FUNCTION HANDLES
	properties (SetAccess = protected, Hidden, Nontunable)
		MorphOpFcn
	end
	properties (Dependent, Hidden, Nontunable)
		MorphologicalOps % {'clean',1; 'close',1; 'majority',1}		
	end
	
	
	
	
	
	% CONSTRUCTOR
	methods
		function obj = RoiGenerator(varargin)
			setProperties(obj,nargin,varargin{:});			
			parseConstructorInput(obj,varargin(:));
			setPrivateProps(obj);			
			obj.CanUseBuffer = true;
			obj.CanUseInteractive = true;
		end		
	end
		
	% BASIC INTERNAL SYSTEM METHODS
	methods (Access = protected)
		function setupImpl(obj, data)
			% CHECK INPUT
			sz = size(data);
			obj.FrameSize = sz(1:2);
			obj.InputDataType = class(data);
			inputNumFrames = size(data,3);
			obj.TuningImageDataSet = [];
			if isempty(obj.OutputTypeIdx)
				obj.OutputTypeIdx = getIndex(obj.OutputTypeSet, obj.OutputType);
			end
			
			% PREALLOCATE BUFFERS
			if isempty(obj.BufferSize)
				if obj.UseGpu
					dev = gpuDevice;
					maxBufferSize = 2^(nextpow2(dev.AvailableMemory / (prod(obj.FrameSize)*8))-3);
				else
					maxBufferSize = 256;
				end
				obj.BufferSize = maxBufferSize;
			end
			if obj.UseBuffer
				bufferSize = obj.BufferSize;
				if inputNumFrames == 1
					obj.DataBuffer = repmat(data,1,1,bufferSize);
				else
					obj.DataBuffer = repmat(data,1,1,ceil(bufferSize/inputNumFrames));
				end
			end
			
			% CHECK WHETHER INPUT IS ALREADY ON GPU OR NEEDS TO BE SENT
			if isa(data,'gpuArray')
				obj.UseGpu = true;
			elseif obj.UseGpu
				data = gpuArray(data);
			end
			%#NEW##
			if obj.UseGpu && ~isempty(obj.GpuRetrievedProps)
				pushGpuPropsBack(obj)
				return
			end
			%#NEW##
			obj.CurrentFrameIdx = 0;
			setPrivateProps(obj)
			if ~isempty(obj.MorphologicalOps)
				constructMorphOpFcn(obj);
			end
			
			
			
			if obj.UseGpu
				obj.SegmentationSum = gpuArray.zeros(obj.FrameSize, 'uint32');
			else
				obj.SegmentationSum = zeros(obj.FrameSize, 'uint32');
			end
			
			nPastFrames = obj.pRecurrenceFilterNumFrames;
			if nPastFrames >= 1
				bwFg = findPixelForeground(obj, data);
				if nPastFrames <= size(bwFg,3)
					obj.ForegroundBuffer = bwFg(:,:,nPastFrames:-1:1);
				else
					obj.ForegroundBuffer = repmat(bwFg(:,:,1), 1, 1, nPastFrames);
				end
			end
			obj.OutputTypeIdx = getIndex(obj.OutputTypeSet, obj.OutputType);
			outputSample = processData(obj, data);
			if isa(outputSample, 'gpuArray')
				obj.OutputDataType = classUnderlying(outputSample);
			else
				obj.OutputDataType = class(outputSample);
			end			
		end
		function varargout = stepImpl(obj, data)
			
			% LOCAL VARIABLES
			n = obj.CurrentFrameIdx;
			inputNumFrames = size(data,3);
						
			if obj.pUseBuffer
				% LOCAL BUFFER VARIABLES
				bufferSize = obj.BufferSize;
				k = rem(n,bufferSize)+1;
				
				% DETERMINE WHICH/WHERE FRAMES GO INTO CURRENT/UNFILLED BUFFER
				bufIdx = k:k+inputNumFrames-1;
				fitsInBuffer = (bufIdx <= bufferSize);
				
				% PUT INPUT INTO FRAME-BUFFER
				obj.DataBuffer(:,:,bufIdx(fitsInBuffer)) = data(:,:,fitsInBuffer);
				
				% RUN ROI-GENERATION IF BUFFER IS FULL
				if bufIdx(end) >= bufferSize
					fullBuffer = obj.DataBuffer;
					
					% SEND BUFFERED DATA TO GPU IF NOT THERE ORIGINALLY
					if obj.pUseGpu && ~isa(fullBuffer, 'gpuArray')
						fullBuffer = gpuArray(fullBuffer);
					end
					
					% CALL MAIN PROCESSING FUNCTION
					output = processData(obj, fullBuffer);
					obj.OutputAvailable = true;
				else
					obj.OutputAvailable = false;
					output = [];
				end
				
				% PUT ANY REMAINING INPUT INTO NEXT BUFFER
				if any(~fitsInBuffer)
					nOver = nnz(~fitsInBuffer);
					obj.DataBuffer(:,:,1:nOver) = data(~fitsInBuffer);
				end
				
				
			else
				% UNBUFFERED PROCESSING
				if obj.pUseGpu && ~isa(data, 'gpuArray')
					data = gpuArray(data);
				end
				output = processData(obj, data);
			end
			
			% UPDATE NUMBER OF FRAMES
			obj.CurrentFrameIdx = n + inputNumFrames;
			
			if nargout
				varargout{1} = output;
			end
		end		
		function releaseImpl(obj)
			fetchPropsFromGpu(obj)
		end
	end		
	
	% RUN-TIME HELPER METHODS
	methods (Access = protected)
		function output = processData(obj, F)
									
			% RUN INTENSITY-BASED SEGMENTATION OF FOREGROUND
			bwFg = findPixelForeground(obj, F);
			
			% APPLY BINARY RECURRENCE FILTER TO FOREGROUND
			bwFg = recurrenceFilterForeground(obj, bwFg);
						
			% APPLY MORPHOLOGICAL SPATIAL FILTERING TO FOREGROUND
			bwFg = spatialFilterForeground(obj, bwFg);
			
			% FIND CONTIGUOUS PIXEL REGIONS WITHIN SIZE CONSTRAINTS (LABEL MATRIX)
			lm = filterSegmentedRegions(obj, bwFg);
			
			% GENERATE REGION STATISTICS AND LINK REGIONS
			% 			rp = generateLinkedRegions(obj, lm, F);
			
			% PROVIDE VARIABLE OUTPUT DEPENDING ON OUTPUT-TYPE PROPERTY
			switch obj.OutputTypeIdx
				case 1 % LabelMatrix
					output = lm;
				case 2 % ConnComp
					output = obj.ConnComp;
				case 3 % Mask
					output = logical(lm);
				otherwise
					output = lm;
			end
			
		end
		function bwFg = findPixelForeground(obj, F, maxExpectedDiameter)			
			% Returns potential foreground pixels as logical array
			if nargin < 2
				F = obj.DataBuffer;
			end
			if nargin < 3
				maxExpectedDiameter = obj.pMaxExpectedDiameter;
			end
						
			% RUN FOR MAX-EXPECTED DIAMETER AND SMALLER POWERS-OF-2
			if maxExpectedDiameter > 8
				dsVec = [2.^(2:nextpow2(maxExpectedDiameter)-1), maxExpectedDiameter];
			else
				dsVec = maxExpectedDiameter;
			end
			if isa(F, 'gpuArray')
				bwFg = gpuArray.false(size(F));
			else
				bwFg = false(size(F));
			end
				
			% CALL EXTERNAL FUNCTION FOR VARIABLE INPUT
			if isa(F, 'gpuArray')
				% ARRAYFUN ON GPU	
				[nrows,ncols,~] = size(F);
				% IMMEDIATE NEIGHBORS: SINGLE-PIXEL-SHIFTED ARRAYS (4-CONNECTED)
				Fu = F([1, 1:nrows-1], :, :);
				Fd = F([2:nrows, nrows], :,:);
				Fl = F(:, [1, 1:ncols-1],:);
				Fr = F(:, [2:ncols, ncols], :);
				% SPACED SURROUNDING PIXELS: MULTI-PIXEL-SHIFTED ARRAYS
				for k=1:length(dsVec)
					ds = dsVec(k);
					Su = F([ones(1,ds), 1:nrows-ds], :, :);
					Sd = F([ds+1:nrows, nrows.*ones(1,ds)], :, :);
					Sl = F(:, [ones(1,ds), 1:ncols-ds], :);
					Sr = F(:, [ds+1:ncols, ncols.*ones(1,ds)], :);
					bwFg = bwFg | arrayfun(@findPixelForegroundElementWise, F, Fu, Fr, Fd, Fl, Su, Sr, Sd, Sl);					
				end
			else
				% VECTORIZED OPS ON CPU OR GPU
				for k=1:length(dsVec)
					bwFg = bwFg | findPixelForegroundArrayWise(F,dsVec(k));
				end
			end
			% TODO: Benchmark, arraywise versus elementwise function
			% ARRAYFUN BENCHMARK (gpu):
			%			1.0000    0.1109
			%			2.0000    0.0057
			%			4.0000    0.0057
			%			8.0000    0.0057
			%			16.0000   0.0057
			%			32.0000   0.0380
			% VECTORIZED BENCHMARK (gpu):
			% 		1.0000    0.1668
			%     2.0000    0.0228
			%     4.0000    0.0163
			%     8.0000    0.0170
			%    16.0000    0.1303
			%    32.0000    0.2430
			% VECTORIZED BENCHMARK (cpu):
			% 		1.0000    0.3133
			%     2.0000    0.5230
			%     4.0000    1.0212
			%     8.0000    2.0502
			%    16.0000    4.1064
			%    32.0000    8.9179
		end
		function bwFg = recurrenceFilterForeground(obj, bwFg, numPastFrames)
			
			% RETRIEVE FROM BUFFER & APPLY TEMPORAL FILTER IF SPECIFIED
			if nargin < 3
				numPastFrames = obj.pRecurrenceFilterNumFrames;
			end
			if isempty(numPastFrames) || numPastFrames < 1				
				return
			end
			
			% LOCAL VARIABLES
			fullFrameSize = obj.FrameSize;
			nRows = fullFrameSize(1);
			nCols = fullFrameSize(2);
			numFrames = size(bwFg,3); %obj.BufferSize;
			
			% BUFFERED FOREGROUND
			bwBufferedFg = cat(3, obj.ForegroundBuffer, bwFg);			
			m = size(bwBufferedFg,3);
			nextBufIdx = (m-numPastFrames+1):m;
			obj.ForegroundBuffer(:,:,1:numPastFrames) = bwBufferedFg(:,:,nextBufIdx); % end-nPastFrames+1:end
			
			
			% INDEXED EXPANSION TO PAST FRAMES IN LOGICAL FILTERING OP
			idx = bsxfun(@plus, [0:numFrames-1]', 1:numPastFrames);
			
			% ANY PIXEL MATCHES BETWEEN CURRENT FRAME & PREVIOUS FRAMES ARE USED IN FOREGROUND
			% 				try
			bwFg = squeeze(any( bsxfun(@and,...
				bwBufferedFg(:,:,idx(:,end)+1),... %nPastFrames+1:end
				reshape(bwBufferedFg(:,:,idx(:)), nRows, nCols, numFrames, numPastFrames)), 4));
			
		end
		function bwFg = spatialFilterForeground(obj, bwFg)
			N = size(bwFg,3);
			if ~isempty(obj.MorphOpFcn)
				morphOpFcn = obj.MorphOpFcn;
			else
				morphOpFcn = @(F) bwmorph(bwmorph(bwmorph( F, 'clean'), 'close'), 'majority');
				obj.MorphOpFcn = morphOpFcn;
			end
			% 			if obj.UsePct && N>16
			% 				parfor kp = 1:N
			% 					bwFg(:,:,kp) = bwmorph(bwmorph(bwmorph(bwmorph( bwFg(:,:,kp), 'clean'), 'close'), 'majority'),'fill');
			% 					% 					bwFg(:,:,kp) = morphOpFcn(bwFg(:,:,kp));
			% 				end
			% 			else
			for kp = 1:N
				% 				bwFg(:,:,kp) = bwmorph(bwmorph(bwmorph(bwmorph( bwFg(:,:,kp), 'clean'), 'close'), 'majority'),'fill');
				bwFg(:,:,kp) = morphOpFcn(bwFg(:,:,kp));
			end
			% 			end
			
		end
		function lm = filterSegmentedRegions(obj, bwFg, pixAreaLimit)
			
			% PIXEL-AREA-LIMITS FROM INPUT OR PROPERTY
			if nargin < 3
				pixAreaLimit = [obj.pMinRoiPixArea , obj.pMaxRoiPixArea];
			end			
			
			% LOCAL VARIABLES
			if (obj.OutputTypeIdx == 2) || ~isa(bwFg, 'gpuArray')
				cc = findConnectedComponents(obj, bwFg, pixAreaLimit);
				lm = labelmatrix(cc);
			else
				lm = findLabelMatrix(obj, bwFg, pixAreaLimit);
			end
			
			% MATCH & ACCUMULATE LABELS OVER TIME
			obj.SegmentationSum = obj.SegmentationSum + sum(uint32(logical(lm)),3,'native');
			
			
		end
		function cc = findConnectedComponents(obj, bwFg, pixAreaLimit)
			
			% PIXEL-AREA-LIMITS FROM INPUT OR PROPERTY
			if nargin < 3				
				minArea = obj.pMinRoiPixArea;
				maxArea = obj.pMaxRoiPixArea;
			else
				if numel(pixAreaLimit) == 2
					minArea = pixAreaLimit(1);
					maxArea = pixAreaLimit(2);
				elseif numel(pixAreaLimit) == 1
					minArea = pixAreaLimit;
					maxArea = inf;
				else
					minArea = obj.pMinRoiPixArea;
					maxArea = obj.pMaxRoiPixArea;
				end
			end			
			
			% LOCAL VARIABLES
			N = obj.CurrentFrameIdx;
			inputNumFrames = size(bwFg,3);			
			inputFrameIdx = N + (1:inputNumFrames);			
			numPixPerFrame = obj.FrameSize(1)*obj.FrameSize(2);
			
			% PASS LOGICAL ARRAY TO MATLAB BUILTIN BWCONNCOMP
			if isa(bwFg,'gpuArray')
				cc = bwconncomp(gather(bwFg));
			else
				cc = bwconncomp(bwFg);
			end
			
			% REMOVE REGIONS THAT DON'T FIT INITIAL CRITERIA
			% 			overMin = cellfun('length',cc.PixelIdxList) > minArea;
			% 			underMax = cellfun('length',cc.PixelIdxList) <= maxArea*inputNumFrames;
			isComponentValid = true(1,cc.NumObjects);
			for k=cc.NumObjects:-1:1
				pixIdx = cc.PixelIdxList{k};
				frameIdx = inputFrameIdx(ceil(pixIdx./numPixPerFrame));
				bwFrameExpandedIdx = bsxfun(@eq, frameIdx(:), frameIdx(1):frameIdx(end));
				isOverMin = any(bsxfun(@and, bwFrameExpandedIdx, sum(bwFrameExpandedIdx,1) >= minArea), 2);
				isUnderMax = any(bsxfun(@and, bwFrameExpandedIdx, sum(bwFrameExpandedIdx,1) <= maxArea), 2);
				bwValid = isOverMin & isUnderMax;
				if any(bwValid)
					validFrames = max(bsxfun(@times, frameIdx(:), bsxfun(@and, bwFrameExpandedIdx, bwValid)), [], 1);
					validFrames = validFrames(validFrames>0);
					frameIdx = frameIdx(bwValid);
					pixIdx = pixIdx(bwValid);
					cc.Frames{k} = validFrames;
					cc.FrameIdx{k} = frameIdx;
					cc.PixelIdxList{k} = pixIdx;
				else
					isComponentValid(k) = false;
				end				
			end
			cc.NumObjects = nnz(isComponentValid);
			cc.PixelIdxList = cc.PixelIdxList(isComponentValid);
			obj.ConnComp = cc;
		end
		function lm = findLabelMatrix(obj, input, pixAreaLimit)
			% This function assumes that if the input is a structure with fields matching the output of
			% builtin bwconncomp structure, then the pixel-area-limits have already been applied in the
			% findConnectedComponents method
			
			if isstruct(input) && isfield(input, 'NumObjects')
				% USE BUILT-IN FUNCTION TO COMPUTE LABEL-MATRIX FROM CONN-COMP STRUCTURE
				lm = labelmatrix(input);
			else
				% PIXEL-AREA-LIMITS FROM INPUT OR PROPERTY
				if nargin < 3
					minArea = obj.pMinRoiPixArea;
					maxArea = obj.pMaxRoiPixArea;
				else
					if numel(pixAreaLimit) == 2
						minArea = pixAreaLimit(1);
						maxArea = pixAreaLimit(2);
					elseif numel(pixAreaLimit) == 1
						minArea = pixAreaLimit;
						maxArea = inf;
					else
						minArea = obj.pMinRoiPixArea;
						maxArea = obj.pMaxRoiPixArea;
					end
				end
				
				% USE BWLABEL ON LOGICAL ARRAY INPUT AFTER RESHAPING TO 2D
				lm = reshape(uint32(...
					bwlabel(reshape( input , size(input,1),[],1))...
					), size(input,1),size(input,2),[]);
				
				% REMOVE REGIONS THAT DON'T FIT INITIAL CRITERIA % .609 seconds
				numFrames = size(lm,3);
				allLabels = (1:max(lm(:)));
				
				
				% 				labelArea = accumarray(lm(:), 1, [max(lm(:)),1]);
				labelArea = histcounts(lm, .5+[0,allLabels]);
				
				
				areaValid = (labelArea >= minArea) & (labelArea <= maxArea);
				if nnz(areaValid) < nnz(~areaValid);
					validLabels = allLabels( areaValid );
					for k=1:numFrames
						lm(:,:,k) = lm(:,:,k) .* uint32(any(...
							bsxfun(@eq, lm(:,:,k), shiftdim(validLabels, -1)), 3));
					end
				else
					invalidLabels = allLabels( ~areaValid);
					for k=1:numFrames
						lm(:,:,k) = lm(:,:,k) .* uint32(all(...
							bsxfun(@ne, lm(:,:,k), shiftdim(invalidLabels, -1)), 3));
					end
				end
			end
			
			% MAKE SURE LABEL-MATRIX IS UINT16 FOR CONSISTENCY
			if isa(lm, 'uint8')
				lm = uint16(lm);
			elseif ~isa(lm, 'uint16')
				% OUT-OF-RANGE LABELS ARE WRAPPED AROUND
				idxExceedsRange = lm > 65535;
				while any(idxExceedsRange(:))
					fprintf('exceeds range\n')
					lm(idxExceedsRange) = lm(idxExceedsRange) - 65535;
					idxExceedsRange = lm > 65535;
				end
				lm = uint16(lm);
			end
			
			% SEND RESULT TO PROPERTY OUTPUT PORT
			obj.LabelMatrix = lm;
			obj.Mask = logical(lm);
		end
	end
	
	% TUNING
	methods (Hidden)
		function tuneInteractive(obj)
			% TODO
			
			% STEP 1: EXPECTED CELL DIAMETER (in pixels) -> findPixelForeground
			obj.TuningStep(1).ParameterName = 'MaxExpectedDiameter';
			x = obj.MaxExpectedDiameter;
			if isempty(x)
				x = round(max(obj.FrameSize)/20);
			end
			obj.TuningStep(1).ParameterDomain = [1:x, x+1:10*x];
			obj.TuningStep(1).ParameterIdx = ceil(x);
			obj.TuningStep(1).Function = @findPixelForeground;
			
			% STEP 2: TEMPORAL FILTER SPAN			
			obj.TuningStep(2).ParameterName = 'RecurrenceFilterNumFrames';
			x = obj.RecurrenceFilterNumFrames;
			if isempty(x)
				x = 3;
			end
			maxSpan = min(10*(x+1), size(obj.TuningImageDataSet,3));
			obj.TuningStep(2).ParameterDomain = [0:x x+1:maxSpan];
			obj.TuningStep(2).ParameterIdx = ceil(x+1);
			idx = max(maxSpan+1,obj.TuningImageIdx);
			obj.TuningStep(2).Function = @testRecurrenceFilter;
			
			% STEP 3: SPATIAL FILTER WITH MORPHOLOGICAL OPERATIONS
			numPreviousOps = 2;
			[numMorphOps,~] = size(obj.MorphologicalOps);
			for k = numPreviousOps + (1:numMorphOps)
				opNum = k-numPreviousOps;
				opProp = sprintf('MorphOp%i',opNum);
				obj.TuningStep(k).ParameterName = opProp;
				obj.TuningStep(k).ParameterDomain = obj.morphologicalOpsAvailable;
				if ~isempty(obj.(opProp))
					if iscell(obj.(opProp))
						currentOp = obj.(opProp){1};
					elseif ischar(obj.(opProp))
						currentOp = obj.(opProp);
					else
						currentOp = 'close';
					end					
				else
					currentOp = 'close';
				end
				obj.TuningStep(k).ParameterIdx = find(~cellfun('isempty',strfind(obj.morphologicalOpsAvailable, currentOp)));
				obj.TuningStep(k).Function = @testMorphOpFcn;
			end
		
			setPrivateProps(obj)
			
			% SET UP TUNING WINDOW
			createTuningFigure(obj);			%TODO: can also use for automated tuning?
		
		end
		function tuneAutomated(obj)
			% TODO			
			obj.TuningImageDataSet = [];
		end
		function F = testRecurrenceFilter(obj, F, numPastFrames)
			% This tuning function needs to be implemented as a class-method, unlike most others which can
			% be defined using a function handle to the "RUN-TIME" method that is normally used to process data. This
			% is because the temporal filter RUN-TIME method relies on a buffer of sequential frames that
			% directly precede the current frame, and this buffer will need to be repopulated as the user
			% switches the current RecurrenceFilterNumFrames parameter value (determining the length of the
			% buffer), and also when the user changes parameters affecting the input to this step. This
			% implementation is very inefficient (many redundant or unnecessary calculations) but requires
			% minimal effort to change, and will adapt easily to changes elsewhere in this system. Note:
			% the input 'F' will already be processed by all preceding operations, but the buffer may
			% need to be processed on each call.
			%TODO: FIX
			% CHECK WHETHER A NEW BUFFER NEEDS TO BE COMPUTED (e.g. change of  PRECEDING PARAMETERS)
			% 			persistent lastImageIdx
			% 			persistent lastPrecedingParameterIdx
			% 			persistent lastNumPastFrames
			if nargin < 3
				numPastFrames = obj.RecurrenceFilterNumFrames;
			end
			curIdx = obj.TuningImageIdx;
			numPreviousSteps = find(~strcmpi('RecurrenceFilterNumFrames', {obj.TuningStep.ParameterName}),1,'first');
			bufIdx = max(1, (curIdx-numPastFrames):(curIdx-1));
			obj.ForegroundBuffer = findPixelForeground(obj, gpuArray(obj.TuningImageDataSet(:,:,bufIdx)));
			F = recurrenceFilterForeground(obj, F, numPastFrames);
			% 			% 						numPreviousSteps = obj.TuningCurrentStep - 1;
			% 			if isempty(lastImageIdx)
			% 				lastImageIdx = curIdx;
			% 			end
			% 			if isempty(lastPrecedingParameterIdx)
			% 				lastPrecedingParameterIdx = zeros(1, numPreviousSteps);
			% 			end
			% 			if isempty(lastNumPastFrames)
			% 				lastNumPastFrames = 0;
			% 			end
			% 			if obj.UseGpu && ~isa(F, 'gpuArray')
			% 				F = gpuArray(F);
			% 			end
			%
			% 			% FIX FOREGROUND BUFFER DEPENDING ON CHANGES MADE
			% 			precedingParameterIdx = [obj.TuningStep(1:numPreviousSteps).ParameterIdx];
			% 			if ~all( precedingParameterIdx == lastPrecedingParameterIdx)
			% 				% GRAB NPAST FRAMES IMMEDIATELY PRECEDING THE CURRENT FRAME AND PERFORM ALL OPERATIONS
			% 				idx = max(1, curIdx-numPastFrames : curIdx-1);
			% 				fBuf = performPrecedingSteps(obj.TuningImageDataSet(:,:,idx));
			% 				obj.ForegroundBuffer = fBuf;
			% 			elseif 	(numPastFrames ~= lastNumPastFrames)
			% 				% CURRENT PARAMETER CHANGE
			% 				if (numPastFrames < lastNumPastFrames)
			% 					% DECREASE NUMPASTFRAMES
			% 					if numPastFrames < 1
			% 						fBuf = [];
			% 					else
			% 						idx = (lastNumPastFrames-numPastFrames+1):lastNumPastFrames;
			% 						fBuf = obj.ForegroundBuffer(:,:,idx);
			% 					end
			% 				else
			% 					% INCREASE NUMPASTFRAMES
			% 					idx = max(1, curIdx-numPastFrames : curIdx-lastNumPastFrames-1);
			% 					fBuf = cat(3, performPrecedingSteps(obj.TuningImageDataSet(:,:,idx)), obj.ForegroundBuffer);
			% 				end
			% 				obj.ForegroundBuffer = fBuf;
			% 			else
			% 				if	(curIdx < lastImageIdx)
			% 					frameDiff = lastImageIdx-curIdx;
			% 					idx = max(1, (curIdx-numPastFrames)+(0:frameDiff));
			% 					fBuf = cat(3, performPrecedingSteps(obj.TuningImageDataSet(:,:,idx)),...
			% 						obj.ForegroundBuffer(:,:,1:end-frameDiff));
			% 				elseif (curIdx > lastImageIdx)
			% 					frameDiff = curIdx-lastImageIdx;
			% 					fBuf = cat(3, obj.ForegroundBuffer(:,:,frameDiff:end-frameDiff),...
			% 						performPrecedingSteps(obj.TuningImageDataSet(:,:,lastImageIdx:curIdx-1)));
			% 				end
			% 				obj.ForegroundBuffer = fBuf;
			% 			end
			% CALL NORMAL "RUN-TIME" RECURRENCE FILTER METHOD
			% 			if	(curIdx <= (lastImageIdx))
			% RESTORE FOREGROUND-BUFFER IN ANTICIPATION OF THE IMAGE-INDEX STAYING THE SAME
			% 				fBuf = obj.ForegroundBuffer;
			% 				F = recurrenceFilterForeground(obj, F, numPastFrames);
			% 				obj.ForegroundBuffer = fBuf;
			% 				fprintf('keeping buffered frames\n')
			% 			else
			% 				F = recurrenceFilterForeground(obj, F, numPastFrames);
			% 				fprintf('allowing frame to add to buffer\n')
			% 			end
			
			% 			lastNumPastFrames = numPastFrames;
			% 			lastPrecedingParameterIdx = precedingParameterIdx;
			% 			lastImageIdx = curIdx;
			
			% SUB-FUNCTION: PERFORMS OPERATIONS FROM PREVIOUS TUNING-STEPS TO BUFFER
			function fBuf = performPrecedingSteps(fBuf)
				if obj.UseGpu && ~isa(fBuf, 'gpuArray')
					fBuf = gpuArray(fBuf);
				end
				for k = 1:numPreviousSteps
					fcn = obj.TuningStep(k).Function;
					parameterPropVal = obj.TuningStep(k).ParameterDomain(obj.TuningStep(k).ParameterIdx);
					fBuf = feval( fcn, obj, fBuf, parameterPropVal);
				end
			end
		end
		function bw = testMorphOpFcn(obj, bw, op)			
			if nargin < 3
				fcn = constructMorphOpFcn(obj);
				bw = fcn(bw);
			else
				bw = bwmorph(bw, op{1});
			end			
		end
	end
	
	% INITIALIZATION HELPER METHODS
	methods (Hidden)
		function varargout = constructMorphOpFcn(obj, ops)			
			% CONSTRUCT ANONYMOUS FUNCTION CHAINING MULTIPLE 'BWMORPH' FUNCTION-CALLS
			if nargin < 2
				ops = obj.MorphologicalOps;
			end			
			if ~isempty(ops)
				opNames = ops(:,1);
				if all(cellfun(@ischar, ops(:)))
					opNumRepeat = num2cell(ones(numel(ops),1));
				else
					opNumRepeat = ops(:,2);
				end
				numOps = numel(opNames);
				strFcn = '@(bw) ';
				if any([opNumRepeat{:}]>1)
					for k=1:numOps
						strFcn = [strFcn, 'bwmorph('];
					end
					strFcn = [strFcn, ' bw '];
					for k=1:numOps
						strFcn = [strFcn, sprintf(', ''%s'', %i)', opNames{k}, opNumRepeat{k})];
					end
					fcn = eval(strFcn);
				else
					for k=1:numOps
						strFcn = [strFcn, 'bwmorph('];
					end
					strFcn = [strFcn, ' bw '];
					for k=1:numOps
						strFcn = [strFcn, sprintf(', ''%s'')', opNames{k})];
					end
					fcn = eval(strFcn);
				end
			else
				fcn = @(bw) bwmorph(bwmorph(bwmorph( bw, 'clean'), 'close'), 'majority');
			end
			
			% STR2FUNC(FUNC2STR(... CLEANS THE ANONYMOUS FUNCTION HANDLE OF UNNECESSARY WORKSPACE
			fcn = str2func(func2str(fcn));
			obj.MorphOpFcn = fcn;
			if nargout
				varargout{1} = fcn;
			end
		end
		function setBufferSize(obj, sz)
			obj.BufferSize = sz;
		end
	end
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
	
	% GET FUNCTIONS FOR VALIDATING PROPERTY INPUT
	methods 
		function opList = get.MorphologicalOps(obj)
			% PULLS USER INPUT FROM PROPERTIES NAMED MORPHOP1, MORPHOP2, ETC
			validOps = obj.morphologicalOpsAvailable;
			opPropNum = 1;
			opProp = sprintf('MorphOp%i',opPropNum);
			opNum = 0;
			while isprop(obj, opProp)
				opSpec = obj.(opProp);
				opPropNum = opPropNum + 1;
				opProp = sprintf('MorphOp%i',opPropNum);
				if isempty(opSpec)
					continue
				end
				if iscell(opSpec)
					opName = opSpec{1};
					if (numel(opSpec) == 2) && isnumeric(opSpec{2})
						opRep = opSpec{2};
					else
						opRep = 1;
					end
				elseif ischar(opSpec)
					opName = opSpec;
					opRep = 1;
				else
					continue
				end
				if ~any(strcmpi(opName, validOps))
					continue
				end
				opNum = opNum + 1;
				opList{opNum, 1} = opName;
				opList{opNum, 2} = opRep;
			end
		end
	end
	
	% STATIC HELPER METHODS
	methods (Static)
		function validOperations = morphologicalOpsAvailable()
			% 			validOperations = {...
			% 				     'bothat',...       Subtract the input image from its closing
			% 			       'branchpoints',... Find branch points of skeleton 'bridge',...
			% 			       Bridge previously unconnected pixels 'clean',...        Remove
			% 			       isolated pixels (1's surrounded by 0's) 'close',...        Perform
			% 			       binary closure (dilation followed by 'diag',...         Diagonal fill
			% 			       to eliminate 8-connectivity of 'endpoints',...    Find end points of
			% 			       skeleton 'fill',...         Fill isolated interior pixels (0's
			% 			       surrounded by 'hbreak',...       Remove H-connected pixels
			% 			       'majority',...     Set a pixel to 1 if five or more pixels in its
			% 			       'open',...         Perform binary opening (erosion followed by
			% 			       'remove',...       Set a pixel to 0 if its 4-connected neighbors
			% 			       'shrink',...       With N = Inf, shrink objects to points; shrink
			% 			       'skel',...         With N = Inf, remove pixels on the boundaries
			% 			       'spur',...         Remove end points of lines without removing
			% 			       'thicken',... 'thin',... 'tophat'};
			validOperations = {...
				'bothat',...
				'branchpoints',...
				'bridge',...
				'clean',...
				'close',...
				'diag',...
				'dilate',...
				'endpoints',...
				'erode',...
				'fatten',...
				'fill',...
				'hbreak',...
				'majority',...
				'perim4',...
				'perim8',...
				'open',...
				'remove',...
				'shrink',...
				'skeleton',...
				'spur',...
				'thicken',...
				'thin',...
				'tophat'};
			validOperations = validOperations(:);
		end
		
	end
	
	
	
	
end


















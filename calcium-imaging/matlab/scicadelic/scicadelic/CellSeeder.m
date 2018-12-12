classdef (CaseInsensitiveProperties = true) CellSeeder < scicadelic.SciCaDelicSystem
	% CellSeeder
	%
	% INPUT:
	%
	% OUTPUT:
	%		Array of objects of the 'RegionOfInterest' class, resembling a RegionProps structure (Former
	%		Output) Returns structure array, same size as vid, with fields
	%			bwvid =
	%				RegionProps: [12x1 struct] bwMask: [1024x1024 logical]
	%
	% BENCHMARKING:
	%		8.1ms/frame for 16-frame chunk
	%
	% INTERACTIVE NOTE: This system uses morphological operations from the following list, which can
	%		be applied sequentially to a thresholded logical array of pixels identified as potentially
	%		active:
	% 	     'bothat'       Subtract the input image from its closing
	%        'branchpoints' Find branch points of skeleton 'bridge'       Bridge previously
	%        unconnected pixels 'clean'        Remove isolated pixels (1's surrounded by 0's) 'close'
	%        Perform binary closure (dilation followed by
	%                         erosion)
	%        'diag'         Diagonal fill to eliminate 8-connectivity of
	%                         background
	%        'endpoints'    Find end points of skeleton 'fill'         Fill isolated interior pixels
	%        (0's surrounded by
	%                         1's)
	%        'hbreak'       Remove H-connected pixels 'majority'     Set a pixel to 1 if five or more
	%        pixels in its
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
	%                         with holes shrinks to a ring halfway between the hole and outer boundary
	%        'tophat'       Subtract the opening from the input image
	%
	% See also: BWMORPH GPUARRAY/BWMORPH
	
	
	
	% USER SETTINGS
	properties (Access = public, Nontunable)
		MinExpectedDiameter = 3;
		MaxExpectedDiameter = 10;					% Determines search space for determining foreground & activity
		RecurrenceFilterNumFrames = 1;		% Number of prior frames to compare to current frame in foreground operation, any matches propagate
		MorphOp1 = 'majority'
		MorphOp1Repeat = 3
		MorphOp2 = 'clean'
		MorphOp2Repeat = 1
		MorphOp3 = 'close'
		MorphOp3Repeat = 1
		MorphOp4 = 'open'
		MorphOp4Repeat = 1
		MorphOpChainType = 'And'
	end
	
	% STATES
	properties (SetAccess = protected, Logical)
		OutputAvailable = false
	end
	properties (DiscreteState)
		CurrentFrameIdx
	end
	
	% OUTPUTS
	properties (SetAccess = protected)
		LabelMatrix
		ConnComp
		Mask
		SegmentationSum
	end
	properties (SetAccess = protected, Hidden)
		MorphOpChainTypeSet = matlab.system.StringSet({'And','Or','Xor'})		
	end
	
	% BUFFERS
	properties (SetAccess = protected, Hidden)		
		InputBuffer
		ForegroundBuffer					% Logical array representing unfiltered foreground pixels from all frames in Filled Buffer from pRecurrenceFilterNumFrames to end
	end
	
	% PRIVATE COPIES
	properties (SetAccess = protected, Hidden, Nontunable)
		pMinExpectedDiameter
		pMaxExpectedDiameter
		pRecurrenceFilterNumFrames
	end
	
	% DYNAMIC FUNCTION HANDLES
	properties (SetAccess = protected, Hidden)
		MorphOpFcn
	end
	properties (Dependent, Hidden)
		MorphologicalOps % {'clean',1; 'close',1; 'majority',1}
	end
	
	
	
	
	
	% CONSTRUCTOR
	methods
		function obj = CellSeeder(varargin)
			setProperties(obj,nargin,varargin{:});
			parseConstructorInput(obj,varargin(:));			
			obj.CanUseInteractive = true;
			setPrivateProps(obj);
		end
	end
	
	% BASIC INTERNAL SYSTEM METHODS
	methods (Access = protected)
		function setupImpl(obj, data)
			fprintf('CellSeeder -> SETUP\n')
			
			% INITIALIZE
			fillDefaults(obj)			
			checkInput(obj, data);
			obj.TuningImageDataSet = [];			
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
			
			setPrivateProps(obj)
			nPastFrames = obj.RecurrenceFilterNumFrames;
			if nPastFrames >= 1
				bwFg = findPmiErosion(obj, data, obj.MaxExpectedDiameter);
				if nPastFrames <= size(bwFg,3)
					obj.ForegroundBuffer = bwFg(:,:,nPastFrames:-1:1);
				else
					obj.ForegroundBuffer = repmat(bwFg(:,:,1), 1, 1, nPastFrames);
				end
			end
			
		end
		function output = stepImpl(obj, F)
			
			% LOCAL VARIABLES
			n = obj.CurrentFrameIdx;
			inputNumFrames = size(F,3);
						
			% CELL-SEGMENTAION PROCESSING ON GPU
			F = onGpu(obj, F);
			output = processData(obj, F);
						
			% UPDATE NUMBER OF FRAMES
			obj.CurrentFrameIdx = n + inputNumFrames;
			
		end
		function releaseImpl(obj)
			fetchPropsFromGpu(obj)
		end
	end
	
	% RUN-TIME HELPER METHODS
	methods (Access = protected)
		function bwFg = processData(obj, F)
			
			% RUN INTENSITY-BASED SEGMENTATION OF FOREGROUND
			bwFg = findPmiErosion(obj, F);
			
			% APPLY BINARY RECURRENCE FILTER TO FOREGROUND
			bwFg = recurrenceFilterForeground(obj, bwFg);
			
			% APPLY MORPHOLOGICAL SPATIAL FILTERING TO FOREGROUND
			bwFg = spatialFilterForeground(obj, bwFg);
			
		end
		function bwFg = findPmiErosion(obj, F, minExpectedDiameter)
			% Returns potential foreground pixels as logical array			
			if nargin < 3
				minExpectedDiameter = onGpu(obj, obj.pMinExpectedDiameter);
			end
			displacements = 1:minExpectedDiameter; 
			Fbuf = obj.InputBuffer;
			nBuf = size(Fbuf,3);
			nNew = size(F,3);
			
			if ~isempty(Fbuf)
				Q = cat(3,Fbuf,F);
			else
				Q = F;
			end
			nQ = size(Q,3);
			
			
			[PMI, Hab, P] = pointwiseMutualInformationRunGpuKernel(Q, [], [], displacements);
			pmiMin = min(max(0,PMI),[],3);
			
			
% 			obj.InputBuffer = Q(:,:, max(1,nQ-15):nQ); %TODO
			
			bwFg = bsxfun(@and, F>.1, pmiMin > .05);
			
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
			[nRows, nCols, N] = size(bwFg);
			
			% BUFFERED FOREGROUND
			bwBufferedFg = cat(3, obj.ForegroundBuffer, bwFg);
			m = size(bwBufferedFg,3);
			nextBufIdx = (m-numPastFrames+1):m;
			if isempty(obj.ForegroundBuffer)
				obj.ForegroundBuffer = bwBufferedFg(:,:,nextBufIdx);
			else
				obj.ForegroundBuffer(:,:,1:numPastFrames) = bwBufferedFg(:,:,nextBufIdx); % end-nPastFrames+1:end
			end
			
			% INDEXED EXPANSION TO PAST FRAMES IN LOGICAL FILTERING OP
			idx = bsxfun(@plus, [0:N-1]', 1:numPastFrames);
			
			% ANY PIXEL MATCHES BETWEEN CURRENT FRAME & PREVIOUS FRAMES ARE USED IN FOREGROUND
			% 				try
			bwFg = squeeze(any( bsxfun(@and,...
				bwBufferedFg(:,:,idx(:,end)+1),... %nPastFrames+1:end
				reshape(bwBufferedFg(:,:,idx(:)), nRows, nCols, N, numPastFrames)), 4));
			
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
			% 					bwFg(:,:,kp) = bwmorph(bwmorph(bwmorph(bwmorph( bwFg(:,:,kp), 'clean'), 'close'),
			% 					'majority'),'fill'); % 					bwFg(:,:,kp) = morphOpFcn(bwFg(:,:,kp));
			% 				end
			% 			else
			for kp = 1:N
				% 				bwFg(:,:,kp) = bwmorph(bwmorph(bwmorph(bwmorph( bwFg(:,:,kp), 'clean'), 'close'),
				% 				'majority'),'fill');
				bwFg(:,:,kp) = morphOpFcn(bwFg(:,:,kp));
			end
			% 			end
			
		end
		
	end
	
	% TUNING
	methods (Hidden)
		function tuneInteractive(obj)
			% TODO
			
			% STEP 1: EXPECTED CELL DIAMETER (in pixels) -> findPmiErosion
			obj.TuningStep(1).ParameterName = 'MinExpectedDiameter';
			x = obj.MinExpectedDiameter;
			if isempty(x)
				x = round(max(obj.FrameSize)/20);
			end
			obj.TuningStep(1).ParameterDomain = [1:x, x+1:10*x];
			obj.TuningStep(1).ParameterIdx = ceil(x);
			obj.TuningStep(1).Function = @testPmiErosionFcn;
			obj.TuningStep(1).CompleteStep = true;
			
			% STEP 2: TEMPORAL FILTER SPAN
			obj.TuningStep(2).ParameterName = 'RecurrenceFilterNumFrames';
			x = obj.RecurrenceFilterNumFrames;
			if isempty(x)
				x = 3;
			end
			maxSpan = min(10*(x+1), size(obj.TuningImageDataSet,3));
			obj.TuningStep(2).ParameterDomain = [0:x x+1:maxSpan];
			obj.TuningStep(2).ParameterIdx = ceil(x+1);
			% 			idx = max(maxSpan+1,obj.TuningImageIdx);
			obj.TuningStep(2).Function = @testRecurrenceFilter;
			obj.TuningStep(2).CompleteStep = true;
			
			% STEP 3: SPATIAL FILTER WITH MORPHOLOGICAL OPERATIONS
			numPreviousOps = 2;
			numMorphOps = max(size(obj.MorphologicalOps,1), 4);
			for k = numPreviousOps + (1:2:numMorphOps*2)
				opNum = ceil((k-numPreviousOps)/2);
				opPropStr = sprintf('MorphOp%i',opNum);
				% OPERATION-NAME
				obj.TuningStep(k).ParameterName = opPropStr;
				obj.TuningStep(k).ParameterDomain = cat(1,obj.morphologicalOpsAvailable, {'none'});
				if ~isempty(obj.(opPropStr)) && ischar(obj.(opPropStr))
					currentOp = obj.(opPropStr);
				else
					currentOp = 'close';
				end
				obj.TuningStep(k).ParameterIdx = find(~cellfun('isempty',strfind(obj.morphologicalOpsAvailable, currentOp)));
				obj.TuningStep(k).Function = @testMorphOpFcn;
				obj.TuningStep(k).CompleteStep = false;
				% NUMBER OF OPERATION REPETITIONS
				opPropRep = sprintf('MorphOp%iRepeat',opNum);
				obj.TuningStep(k+1).ParameterName = opPropRep;
				obj.TuningStep(k+1).ParameterDomain = 0:10;
				if ~isempty(obj.(opPropRep)) && isnumeric(obj.(opPropRep))
					currentOpRep = obj.(opPropRep);
				else
					currentOpRep = 1;
				end
				obj.TuningStep(k+1).ParameterIdx = currentOpRep;
				obj.TuningStep(k+1).Function = @testMorphOpFcn;
				obj.TuningStep(k+1).CompleteStep = false;
			end
			obj.TuningStep(k+1).CompleteStep = true;
			
			setPrivateProps(obj)
			
			% SET UP TUNING WINDOW
			createTuningFigure(obj);			%TODO: can also use for automated tuning?
			
		end
		function tuneAutomated(obj)
			% TODO
			obj.TuningImageDataSet = [];
		end
		function F = testPmiErosionFcn(obj, F)
			curIdx = obj.TuningImageIdx;
			bufIdx = max(1, (curIdx-16):(curIdx-1));
			obj.InputBuffer = gpuArray(obj.TuningImageDataSet(:,:,bufIdx));
			F = findPmiErosion(obj, F);
			
		end
		function F = testRecurrenceFilter(obj, F)
			% This tuning function needs to be implemented as a class-method, unlike most others which can
			% be defined using a function handle to the "RUN-TIME" method that is normally used to process
			% data. This is because the temporal filter RUN-TIME method relies on a buffer of sequential
			% frames that directly precede the current frame, and this buffer will need to be repopulated
			% as the user switches the current RecurrenceFilterNumFrames parameter value (determining the
			% length of the buffer), and also when the user changes parameters affecting the input to this
			% step. This implementation is very inefficient (many redundant or unnecessary calculations)
			% but requires minimal effort to change, and will adapt easily to changes elsewhere in this
			% system. Note: the input 'F' will already be processed by all preceding operations, but the
			% buffer may need to be processed on each call.
			%TODO: FIX
			% CHECK WHETHER A NEW BUFFER NEEDS TO BE COMPUTED (e.g. change of  PRECEDING PARAMETERS)
			% 			persistent lastImageIdx persistent lastPrecedingParameterIdx persistent
			% 			lastNumPastFrames
			% 			if nargin < 3
			numPastFrames = obj.RecurrenceFilterNumFrames;
			% 			end
			curIdx = obj.TuningImageIdx;
			% 			numPreviousSteps = find(~strcmpi('RecurrenceFilterNumFrames', {obj.TuningStep.ParameterName}),1,'first');
			bufIdx = max(1, (curIdx-numPastFrames):(curIdx-1));
			obj.ForegroundBuffer = findPmiErosion(obj, gpuArray(obj.TuningImageDataSet(:,:,bufIdx)));
			F = recurrenceFilterForeground(obj, F, numPastFrames);
			
			% SUB-FUNCTION: PERFORMS OPERATIONS FROM PREVIOUS TUNING-STEPS TO BUFFER
			% 			function fBuf = performPrecedingSteps(fBuf)
			% 				if obj.UseGpu && ~isa(fBuf, 'gpuArray')
			% 					fBuf = gpuArray(fBuf);
			% 				end
			% 				for k = 1:numPreviousSteps
			% 					fcn = obj.TuningStep(k).Function;
			% 					parameterPropVal = obj.TuningStep(k).ParameterDomain(obj.TuningStep(k).ParameterIdx);
			% 					fBuf = feval( fcn, obj, fBuf, parameterPropVal);
			% 				end
			% 			end
		end
		function bw = testMorphOpFcn(obj, bw)
			% Used by interactive tuning procedure. Will perform a single operation when each
			% morphological operation name (cell-string) input is passed, but will perform all currently
			% specified steps when user is changing the number of repetitions for the current operation.
			% 			validOps = obj.morphologicalOpsAvailable;
			% 			if iscell(opSpec)
			% 				opName = opSpec{1};
			% 			else
			% 				opName = opSpec;
			% 			end
			% 			if (nargin < 3) || isempty(opName) || ~any(strcmpi(opName, validOps))
			fcn = constructMorphOpFcn(obj);
			bw = fcn(bw);
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
				fcn = @(bw) bw;
			end
			
			% STR2FUNC(FUNC2STR(... CLEANS THE ANONYMOUS FUNCTION HANDLE OF UNNECESSARY WORKSPACE
			fcn = str2func(func2str(fcn));
			obj.MorphOpFcn = fcn;
			if nargout
				varargout{1} = fcn;
			end
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
			opList = {};
			validOps = obj.morphologicalOpsAvailable;
			opPropNum = 1;
			opPropStr = sprintf('MorphOp%i',opPropNum);
			opPropRep = sprintf('MorphOp%iRepeat',opPropNum);
			opNum = 0;
			while isprop(obj, opPropStr)
				opName = obj.(opPropStr);
				if iscell(opName)
					opName = opName{1};
				end
				opRep = obj.(opPropRep);
				if ~isempty(opName) ...
						&& ischar(opName) ...
						&& any(strcmpi(opName, validOps)) ...
						&& (opRep>=1)
					opNum = opNum + 1;
					opList{opNum, 1} = opName;
					opList{opNum, 2} = opRep;
				end
				opPropNum = opPropNum + 1;
				opPropStr = sprintf('MorphOp%i',opPropNum);
				opPropRep = sprintf('MorphOp%iRepeat',opPropNum);
			end
		end
	end
	
	% STATIC HELPER METHODS
	methods (Static)
		function validOperations = morphologicalOpsAvailable()
			% 			validOperations = {...
			% 				     'bothat',...       Subtract the input image from its closing
			% 			       'branchpoints',... Find branch points of skeleton 'bridge',... Bridge
			% 			       previously unconnected pixels 'clean',...        Remove isolated pixels (1's
			% 			       surrounded by 0's) 'close',...        Perform binary closure (dilation followed
			% 			       by 'diag',...         Diagonal fill to eliminate 8-connectivity of
			% 			       'endpoints',...    Find end points of skeleton 'fill',...         Fill isolated
			% 			       interior pixels (0's surrounded by 'hbreak',...       Remove H-connected pixels
			% 			       'majority',...     Set a pixel to 1 if five or more pixels in its 'open',...
			% 			       Perform binary opening (erosion followed by 'remove',...       Set a pixel to 0
			% 			       if its 4-connected neighbors 'shrink',...       With N = Inf, shrink objects to
			% 			       points; shrink 'skel',...         With N = Inf, remove pixels on the boundaries
			% 			       'spur',...         Remove end points of lines without removing 'thicken',...
			% 			       'thin',... 'tophat'};
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

































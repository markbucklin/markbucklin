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
	properties (Access = public)
		OutputType = 'LabelMatrix'
		MaxExpectedDiameter = 30;					% Determines search space for determining foreground & activity
		RecurrenceFilterNumFrames = 3;		% Number of prior frames to compare to current frame in foreground operation, any matches propagate
		MinRoiPixArea = 35;								% previously 50
		MaxRoiPixArea = 300;							% previously 350, then 650, then 250
		MorphologicalOps = {'clean',1; 'close',1; 'majority',1}
		PctActiveUpperLim= 4.5;						% .01 = 10K pixels (15-30 cells?)
		PctActiveLowerLim = .05;					% previous values: 500, 250
		MaxRoiEccentricity = .93;					% previously .92
		MaxPerimOverSqArea = 6;						% circle = 3.5449, square = 4 % Previousvalues: [6.5  ]
		MinPerimOverSqArea = 3.0;					% previously 3.5 PERIMETER / SQRT(AREA)
	end
	
	% STATES
	properties (SetAccess = protected, Logical)
		OutputAvailable
	end
	
	% OUTPUTS
	properties (SetAccess = protected)
		Roi
		LabelMatrix
		ConnComp
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
	properties (SetAccess = protected, Hidden)
		pMaxExpectedDiameter
		pRecurrenceFilterNumFrames
		pMinRoiPixArea
		pMaxRoiPixArea
		pMorphologicalOps
		pUseBuffer
	end
	
	% DYNAMIC FUNCTION HANDLES
	properties (SetAccess = protected, Hidden)
		MorphOpFcn
		MorphOp1 = 'clean'
		MorphOp2 = 'close'
		MorphOp3 = 'majority'
	end
	
	
	
	
	
	% CONSTRUCTOR
	methods
		function obj = RoiGenerator(varargin)
			setProperties(obj,nargin,varargin{:});
			parseConstructorInput(obj,varargin(:));
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
			if isa(data,'gpuArray')
				obj.UseGpu = true;
			end
			% 			if obj.UseGpu && ~isempty(obj.GpuRetrievedProps)
			% 				pushGpuPropsBack(obj)
			% 				return
			% 			end
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
				% 			obj.UnfilledBuffer = repmat(data,1,1,bufferSize);
				if inputNumFrames == 1
					obj.DataBuffer = repmat(data,1,1,bufferSize);
				else
					obj.DataBuffer = repmat(data,1,1,ceil(bufferSize/inputNumFrames));
				end
			end
			obj.NFrames = 0;
			setPrivateProps(obj)
			bwFg = findPixelForeground(obj, data);
			nPastFrames = obj.pRecurrenceFilterNumFrames;
			obj.ForegroundBuffer = bwFg(:,:,nPastFrames:-1:1);
			% 			obj.ForegroundBuffer = cat(3, bwFg(:,:,1:nPastFrames),  bwFg);
			
		end
		function stepImpl(obj, data)
						
			% LOCAL VARIABLES
			n = obj.NFrames;
			inputNumFrames = size(data,3);
			
			% UPDATE NUMBER OF FRAMES
			obj.NFrames = n + inputNumFrames;
			
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
					processData(obj, fullBuffer);
				end
				
				% PUT ANY REMAINING INPUT INTO NEXT BUFFER
				if any(~fitsInBuffer)
					nOver = nnz(~fitsInBuffer);
					obj.DataBuffer(:,:,1:nOver) = data(~fitsInBuffer);
				end
			else
				% UNBUFFERED PROCESSING
				processData(obj, data);
			end
			
		end		
		function releaseImpl(obj)
			fetchPropsFromGpu(obj)
		end
	end		
	
	% RUN-TIME HELPER METHODS
	methods (Access = protected)
		function varargout = processData(obj, F)
			
			% LOCAL VARIABLES
						
			% RUN INTENSITY-BASED SEGMENTATION OF FOREGROUND
			bwFg = findPixelForeground(obj, F);
			
			% APPLY BINARY RECURRENCE FILTER TO FOREGROUND
			bwFg = recurrenceFilterForeground(obj, bwFg);
						
			% APPLY MORPHOLOGICAL SPATIAL FILTERING TO FOREGROUND
			bwFg = spatialFilterForeground(obj, bwFg);
			
			% FIND CONTIGUOUS PIXEL REGIONS (3D CONNECTED COMPONENTS)
			cc = findContiguousRegions(obj, bwFg);
			
			
			lm = labelmatrix(cc);			
			
			% SEND RESULTS TO OUTPUT PORTS
			obj.ConnComp = cc;
			obj.LabelMatrix = uint16(lm);
			
			if nargout
				varargout{1} = cc;
				if nargout > 1
					varargout{2} = lm;
				end
			end
			
		end
		function bwFg = findPixelForeground(obj, F, ds)
			% Returns potential foreground pixels as logical array
			if nargin < 2
				F = obj.DataBuffer;
			end
			if nargin < 3
				ds = ceil(obj.pMaxExpectedDiameter/2);
			end
			% RUNNING USING ARRAYFUN ON GPU OR BSXFUN ON GPU
			if isa(F, 'gpuArray')
				[nrows,ncols,~] = size(F);
				Fu = F([1, 1:nrows-1], :, :);
				Fd = F([2:nrows, nrows], :,:);
				Fl = F(:, [1, 1:ncols-1],:);
				Fr = F(:, [2:ncols, ncols], :);
				Su = F([ones(1,ds), 1:nrows-ds], :, :);
				Sd = F([ds+1:nrows, nrows.*ones(1,ds)], :, :);
				Sl = F(:, [ones(1,ds), 1:ncols-ds], :);
				Sr = F(:, [ds+1:ncols, ncols.*ones(1,ds)], :);
				bwFg = arrayfun(@findPixelForegroundElementWise, F, Fu, Fr, Fd, Fl, Su, Sr, Sd, Sl);
			else
				bwFg = findPixelForegroundArrayWise(F,ds);
			end
		end
		function bwFg = recurrenceFilterForeground(obj, bwFg, numPastFrames)
			
			% RETRIEVE FROM BUFFER & APPLY TEMPORAL FILTER IF SPECIFIED
			if nargin < 3
				numPastFrames = obj.pRecurrenceFilterNumFrames;
			end
			if isempty(numPastFrames) || numPastFrames < 1				
				return
			else
				
				% INITIALIZE BUFFER
				% 				if isempty(obj.ForegroundBuffer)
				% 					obj.ForegroundBuffer = bwFg(:,:,nPastFrames:-1:1);
				% 				end
				
				% LOCAL VARIABLES
				fullFrameSize = obj.FrameSize;
				nRows = fullFrameSize(1);
				nCols = fullFrameSize(2);
				numFrames = size(bwFg,3); %obj.BufferSize;
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
					% 				catch
					% 					bwBufferedFg = gather(bwBufferedFg);
					% 					bwFg = gpuArray(...
					% 						squeeze(any( bsxfun(@and,...
					% 						bwBufferedFg(:,:,idx(:,end)+1),...
					% 						reshape(bwBufferedFg(:,:,idx(:)), nRows, nCols, numFrames, nPastFrames)), 4)));
					% 				end
				% SHIFT UNFILTERED INPUT INTO BUFFER
				% 					obj.ForegroundBuffer = unfilteredBwFg;
			end			
		end
		function bwFg = spatialFilterForeground(obj, bwFg)			
			N = size(bwFg,3);
			% 			if ~isempty(obj.MorphOpFcn)
			% 				morphOpFcn = obj.MorphOpFcn;
			% 			else
			% 				morphOpFcn = @(F) bwmorph(bwmorph(bwmorph( F, 'clean'), 'close'), 'majority');
			% 				obj.MorphOpFcn = morphOpFcn;
			% 			end
			if obj.UsePct && N>16
				parfor kp = 1:N
					bwFg(:,:,kp) = bwmorph(bwmorph(bwmorph( bwFg(:,:,kp), 'clean'), 'close'), 'majority');
					% 					bwFg(:,:,kp) = morphOpFcn(bwFg(:,:,kp));
				end
			else
				for kp = 1:N
					bwFg(:,:,kp) = bwmorph(bwmorph(bwmorph( bwFg(:,:,kp), 'clean'), 'close'), 'majority');
					% 					bwFg(:,:,kp) = morphOpFcn(bwFg(:,:,kp));
				end
			end
		end
		function [cc, lm] = findContiguousRegions(obj, bwFg)
			% LOCAL VARIABLES
			minArea = obj.pMinRoiPixArea;
			maxArea = obj.pMaxRoiPixArea;
			N = obj.NFrames;
			inputNumFrames = size(bwFg,3);
			
			% PASS LOGICAL ARRAY TO MATLAB BUILTIN BWCONNCOMP
			if isa(bwFg,'gpuArray')
				cc = bwconncomp(gather(bwFg));
			else
				cc = bwconncomp(bwFg);
			end
			
			% REMOVE REGIONS THAT DON'T FIT INITIAL CRITERIA
			overMin = cellfun('length',cc.PixelIdxList) > minArea;
			underMax = cellfun('length',cc.PixelIdxList) <= maxArea*inputNumFrames;
			cc.PixelIdxList = cc.PixelIdxList(overMin & underMax);
			cc.NumObjects = nnz(overMin & underMax);
			
			% ADD FRAME NUMBERS TO CONNECTED-COMPONENT STRUCTURE			
			cc.Frames =  N - inputNumFrames + (1:inputNumFrames);
			
			
			% STORE CONNECTED COMPONENT STRUCTURES IN PROPERTY
			% 			if isempty(obj.ConnComp)
			% 			obj.ConnComp = cc;
			% 			else
			% 				obj.ConnComp(numel(obj.ConnComp)+1) = cc;
			% 			end
			% 			if nargout
			% 				varargout{1} = cc;
% 			end
		end
	end
	
	% TUNING
	methods (Hidden)
		function tuneInteractive(obj)
			% TODO
			
			
			obj.TuningImageIdx = 1;
			
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
			maxSpan = min(10*x, size(obj.TuningImageDataSet,3));
			obj.TuningStep(2).ParameterDomain = [0:x x+1:maxSpan];
			obj.TuningStep(2).ParameterIdx = ceil(x+1);
			idx = max(maxSpan+1,obj.TuningImageIdx);			
			obj.TuningStep(2).Function = @testRecurrenceFilter;			
			
			% 			% STEP 3: SPATIAL FILTER WITH MORPHOLOGICAL OPERATIONS
			% 			obj.TuningStep(3).ParameterName = 'MorphologicalOps';
			% 			obj.TuningStep(3).ParameterDomain = obj.morphologicalOpsAvailable;
			% 			obj.TuningStep(1).ParameterIdx = find(~cellfun('isempty',strfind(obj.TuningStep(1).ParameterDomain, 'clean')));
			% 			obj.MorphologicalOps = {};
			% 			obj.TuningFunction = @(F, ops) feval(constructMorphOpFcn(obj, ops), F);
			% 			obj.TuningStep = 3;
			%
			% 			obj.MorphologicalOps = obj.TuningStep(1).ParameterDomain(obj.TuningStep(1).ParameterIdx);
			% 			setPrivateProps(obj);
			% 			preOp = obj.MorphologicalOps(:,1);
			% 			obj.TuningFunction = @(F, ops) feval(constructMorphOpFcn(obj, cat(1,preOp,ops)), F);
			% 			obj.TuningStep = 4;
			%
			% 			obj.MorphologicalOps = cat(1,obj.MorphologicalOps(:,1), obj.TuningStep(1).ParameterDomain(obj.TuningStep(1).ParameterIdx));
			% 			setPrivateProps(obj);
			% 			preOp = obj.MorphologicalOps(:,1);
			% 			obj.TuningFunction = @(F, ops) feval(constructMorphOpFcn(obj, cat(1,preOp,ops)), F);
			% 			obj.TuningStep = 5;
			% 			% STEP 4: MIN & MAX AREA OF CONTIGUOUS REGIONS
			% 			obj.MorphologicalOps = cat(1,obj.MorphologicalOps(:,1), obj.TuningStep(1).ParameterDomain(obj.TuningStep(1).ParameterIdx));
			% 			obj.TuningStep = 6;
			
			
			
			% 			close(obj.TuningFigureHandles.fig)
			% 			obj.TuningImageDataSet = [];
			%
			%
			%
			% 			setPrivateProps(obj)
			
			% SET UP TUNING WINDOW
			createTuningFigure(obj);			%TODO: can also use for automated tuning?
			
			% 			evnt.Key = 'downarrow';
			% 			keyFcn(obj,[],evnt)
			% 			evnt.Key = 'rightarrow';
			% 			keyFcn(obj,[],evnt)
		end
		function tuneAutomated(obj)
			% TODO			
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
			
			% CHECK WHETHER A NEW BUFFER NEEDS TO BE COMPUTED (e.g. change of  PRECEDING PARAMETERS)
			persistent lastImageIdx
			persistent lastPrecedingParameterIdx
			persistent lastNumPastFrames
			curIdx = obj.TuningImageIdx;
			numPreviousSteps = find(~strcmpi('RecurrenceFilterNumFrames', {obj.TuningStep.ParameterName}), 1, 'last');
			if isempty(lastImageIdx)
				lastImageIdx = 0;
			end
			if isempty(lastPrecedingParameterIdx)
				lastPrecedingParameterIdx = zeros(1, numPreviousSteps);
			end
			if isempty(lastNumPastFrames)
				lastNumPastFrames = 0;
			end			
			if (curIdx ~= lastImageIdx) ...
					|| ~all( [obj.TuningStep(1:curIdx-1).ParameterIdx] == lastPrecedingParameterIdx) ...
					|| (lastNumPastFrames ~= numPastFrames)
				
				% GRAB NPAST FRAMES IMMEDIATELY PRECEDING THE CURRENT FRAME AND PERFORM ALL OPERATIONS
				if obj.UseGpu && ~isa(obj.TuningImageDataSet, 'gpuArray')
					fBuf = gpuArray( obj.TuningImageDataSet(:,:, max(1, curIdx-numPastFrames : curIdx-1)));
				else
					fBuf = obj.TuningImageDataSet(:,:, max(1, curIdx-numPastFrames : curIdx-1));
				end
				if obj.UseGpu && ~isa(F, 'gpuArray')
					F = gpuArray(F);
				end
				for k = 1:numPreviousSteps
					fcn = obj.TuningStep(k).Function;
					parameterPropVal = obj.TuningStep(k).ParameterDomain(obj.TuningStep(k).ParameterIdx);
					fBuf = feval( fcn, obj, fBuf, parameterPropVal);
				end
				
				% PUT NPAST FRAMES IN FOREGROUND BUFFER
				obj.ForegroundBuffer = fBuf;
			else
				fBuf = obj.ForegroundBuffer;
			end
			
			% CALL NORMAL "RUN-TIME" TEMPORAL FILTER METHOD
			F = recurrenceFilterForeground(obj, F, numPastFrames);
			
			% RESTORE FOREGROUND-BUFFER IN ANTICIPATION OF THE IMAGE-INDEX STAYING THE SAME
			obj.ForegroundBuffer = fBuf;
			
		end
	end
	
	% INITIALIZATION HELPER METHODS
	methods (Hidden)
		function varargout = constructMorphOpFcn(obj, ops)
			setPrivateProps(obj)
			if nargin < 2
				ops = obj.pMorphologicalOps;
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
	
	% SET FUNCTIONS FOR VALIDATING PROPERTY INPUT
	methods 
		function set.MorphologicalOps(obj, ops)
			validOps = obj.morphologicalOpsAvailable;
			if iscell(ops)
				if all(cellfun(@ischar, ops(:)))
					% no number of repetitions given e.g. {'clean','close','majority'} -> default to 1
					ops = cat(2, ops(:), num2cell(ones(numel(ops),1)));
				elseif nnz(cellfun(@ischar, ops(:))) ~= nnz(cellfun(@isnumeric, ops(:)))
					% TODO: deal with crap-input or just throw error
				end
				opNames = ops(:,1);
				opNumRepeat = ops(:,2);
				for k=1:numel(opNames)
					if ~any(strcmpi(opNames{k}, validOps))
						opNames(k) = [];
						opNumRepeat(k) = [];
					end
				end
				ops = cat(2, opNames(:), opNumRepeat(:));
			elseif ischar(ops)
				ops = {ops, 1};
			else
				ops = {};
			end
			obj.MorphologicalOps = ops;
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
		function validStats = regionPropStatsAvailable()
			validStats.shapeStats = {
				'Area'
				'Centroid'
				'BoundingBox'
				'SubarrayIdx'
				'MajorAxisLength'
				'MinorAxisLength'
				'Eccentricity'
				'Orientation'
				'Image'
				'Extrema'
				'EquivDiameter'
				'Extent'
				'PixelIdxList'
				'PixelList'};
			
			validStats.pixelValueStats = {
				'PixelValues'
				'WeightedCentroid'
				'MeanIntensity'
				'MinIntensity'
				'MaxIntensity'};
			
			validStats.basicStats = {
				'Area'
				'Centroid'
				'BoundingBox'};
		end
	end
	
	
	
	
end





















% 
% 
% function tuneInteractive(obj,tunestep)
% 			% TODO
% 			if isLocked(obj)
% 				release(obj)
% 			end
% 			if nargin < 2
% 				tunestep = 0;
% 			end
% 			switch tunestep
% 				case 0 % SET UP TUNING WINDOW
% 					createTuningFigure(obj);
% 					% 					obj.TuningImageIdx = ceil(size(obj.TuningImageDataSet,3)/2);
% 					obj.TuningImageIdx = 1;
% 					tuneInteractive(obj, 1);					
% 				case 1 % STEP 1: EXPECTED CELL DIAMETER (in pixels) -> findPixelForeground
% 					obj.TuningStep(1).ParameterName = 'MaxExpectedDiameter';
% 					x = obj.MaxExpectedDiameter;
% 					if isempty(x)
% 						x = round(max(obj.FrameSize)/20);
% 					end
% 					obj.TuningStep(1).ParameterDomain = [1:x, x+1:10*x];
% 					obj.TuningStep(1).ParameterIdx = ceil(x);
% 					obj.TuningFunction = @(F,ds) findPixelForegroundArrayWise(F,ds);
% 					obj.TuningStep = 1;
% 				case 2 % STEP 2: TEMPORAL FILTER SPAN
% 					obj.MaxExpectedDiameter = obj.TuningStep(1).ParameterDomain(obj.TuningStep(1).ParameterIdx);
% 					setPrivateProps(obj)
% 					obj.TuningImageDataSet = findPixelForeground(obj, obj.TuningImageDataSet);
% 					obj.TuningStep(1).ParameterName = 'RecurrenceFilterNumFrames';
% 					x = obj.RecurrenceFilterNumFrames;
% 					if isempty(x)
% 						x = 3;
% 					end
% 					maxSpan = min(10*x, size(obj.TuningImageDataSet,3));
% 					obj.TuningStep(1).ParameterDomain = [0:x x+1:maxSpan];
% 					obj.TuningStep(1).ParameterIdx = ceil(x+1);
% 					idx = max(maxSpan+1,obj.TuningImageIdx);
% 					obj.TuningImageIdx = idx-maxSpan:idx;
% 					obj.TuningFunction = @(F,nPastFrames) any(bsxfun(@and, F(:,:,end-nPastFrames:end-1), F(:,:,end)),3);					
% 					obj.TuningStep = 2;
% 					% 				case 3 % STEP 3: SPATIAL FILTER WITH MORPHOLOGICAL OPERATIONS
% 					% 					obj.RecurrenceFilterNumFrames = obj.TuningStep(1).ParameterDomain(obj.TuningStep(1).ParameterIdx);
% 					% 					setPrivateProps(obj)
% 					% 					obj.TuningImageDataSet = recurrenceFilterForeground(obj, obj.TuningImageDataSet);
% 					% 					obj.TuningStep(1).ParameterName = 'MorphologicalOps';
% 					% 					obj.TuningImageIdx = obj.TuningImageIdx(end);
% 					%
% 					% 					obj.TuningStep(1).ParameterDomain = obj.morphologicalOpsAvailable;
% 					% 					obj.TuningStep(1).ParameterIdx = find(~cellfun('isempty',strfind(obj.TuningStep(1).ParameterDomain, 'clean')));
% 					% 					obj.MorphologicalOps = {};
% 					% 					obj.TuningFunction = @(F, ops) feval(constructMorphOpFcn(obj, ops), F);
% 					% 					obj.TuningStep = 3;
% 					% 				case 4
% 					% 					obj.MorphologicalOps = obj.TuningStep(1).ParameterDomain(obj.TuningStep(1).ParameterIdx);
% 					% 					setPrivateProps(obj);
% 					% 					preOp = obj.MorphologicalOps(:,1);
% 					% 					obj.TuningFunction = @(F, ops) feval(constructMorphOpFcn(obj, cat(1,preOp,ops)), F);
% 					% 					obj.TuningStep = 4;
% 					% 				case 5
% 					% 					obj.MorphologicalOps = cat(1,obj.MorphologicalOps(:,1), obj.TuningStep(1).ParameterDomain(obj.TuningStep(1).ParameterIdx));
% 					% 					setPrivateProps(obj);
% 					% 					preOp = obj.MorphologicalOps(:,1);
% 					% 					obj.TuningFunction = @(F, ops) feval(constructMorphOpFcn(obj, cat(1,preOp,ops)), F);
% 					% 					obj.TuningStep = 5;
% 					% 					case 6 % STEP 4: MIN & MAX AREA OF CONTIGUOUS REGIONS
% 					% 						obj.MorphologicalOps = cat(1,obj.MorphologicalOps(:,1), obj.TuningStep(1).ParameterDomain(obj.TuningStep(1).ParameterIdx));
% 					% 						obj.TuningStep = 6;
% 				otherwise
% 					close(obj.TuningFigureHandles.fig)
% 					obj.TuningImageDataSet = [];
% 			end
% 			setPrivateProps(obj)
% 			evnt.Key = 'downarrow';
% 			keyFcn(obj,[],evnt)
% 			evnt.Key = 'rightarrow';
% 			keyFcn(obj,[],evnt)
% 		end




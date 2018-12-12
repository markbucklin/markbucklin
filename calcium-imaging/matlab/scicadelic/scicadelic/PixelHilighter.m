classdef (CaseInsensitiveProperties = true) PixelHilighter < scicadelic.SciCaDelicSystem
	% PixelHilighter
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
		OrFilterNumFrames = 1;
		AndFilterNumFrames = 1;
	end
	
	% STATES
	properties (SetAccess = protected, Logical)		
	end
	properties (DiscreteState)
		CurrentFrameIdx
	end
	
	% BUFFERS
	properties (SetAccess = protected, Hidden)		
		RecurrenceFilterInputBuffer					% Logical array representing unfiltered foreground pixels from all frames in Filled Buffer from pRecurrenceFilterNumFrames to end
		OrFilterInputBuffer
		AndFilterInputBuffer
	end
	
	% PRIVATE COPIES
	properties (SetAccess = protected, Hidden, Nontunable)
		pMinExpectedDiameter
		pMaxExpectedDiameter
		pRecurrenceFilterNumFrames		
		pOrFilterNumFrames
		pAndFilterNumFrames
	end
	
	
	
	
	
	
	
	% CONSTRUCTOR
	methods
		function obj = PixelHilighter(varargin)
			setProperties(obj,nargin,varargin{:});
			parseConstructorInput(obj,varargin(:));			
			obj.CanUseInteractive = true;
			setPrivateProps(obj);
		end
	end
	
	% BASIC INTERNAL SYSTEM METHODS
	methods (Access = protected)
		function setupImpl(obj, data)
			fprintf('PixelHilighter -> SETUP\n')
			
			% INITIALIZE
			fillDefaults(obj)			
			checkInput(obj, data);
			obj.TuningImageDataSet = [];			
			obj.CurrentFrameIdx = 0;
			setPrivateProps(obj)
						
			% PREALLOCATE BUFFERES FOR TEMPORAL FILTERS						
			bwF = findPixelForeground(obj, data, obj.MaxExpectedDiameter);
			m = obj.RecurrenceFilterNumFrames;
			if m >= 1				
				if m <= size(bwF,3)
					obj.RecurrenceFilterInputBuffer = bwF(:,:,m:-1:1);
				else
					obj.RecurrenceFilterInputBuffer = repmat(bwF(:,:,1), 1, 1, m);
				end
				bwF = temporalRecurrenceFilter(obj, bwF);
			end
			m = obj.OrFilterNumFrames;
			if m >= 1
				if m <= size(bwF,3)
					obj.OrFilterInputBuffer = bwF(:,:,m:-1:1);
				else
					obj.OrFilterInputBuffer = repmat(bwF(:,:,1), 1, 1, m);
				end
				bwF = temporalOrFilter(obj, bwF);
			end
			m = obj.AndFilterNumFrames;
			if m >= 1
				if m <= size(bwF,3)
					obj.AndFilterInputBuffer = bwF(:,:,m:-1:1);
				else
					obj.AndFilterInputBuffer = repmat(bwF(:,:,1), 1, 1, m);
				end
				bwF = temporalAndFilter(obj, bwF);
			end
			obj.OutputDataType = class(onGpu(obj, bwF)); % not the best
		end
		function output = stepImpl(obj, data)
			
			% LOCAL VARIABLES
			n = obj.CurrentFrameIdx;
			inputNumFrames = size(data,3);
						
			% CELL-SEGMENTAION PROCESSING ON GPU
			data = onGpu(obj, data);
			output = processData(obj, data);
						
			% UPDATE NUMBER OF FRAMES
			obj.CurrentFrameIdx = n + inputNumFrames;
			
		end
		function releaseImpl(obj)
			fetchPropsFromGpu(obj)
		end
	end
	
	% RUN-TIME HELPER METHODS
	methods (Access = protected)
		function bwF = processData(obj, F)
			
			% RUN INTENSITY-BASED SEGMENTATION OF FOREGROUND
			bwF = findPixelForeground(obj, F);
			
			% APPLY TEMPORAL RECURRENCE FILTER TO FOREGROUND
			bwF = temporalRecurrenceFilter(obj, bwF);
			
			% APPLY TEMPORAL OR FILTER 
			bwF = temporalOrFilter(obj, bwF);
			
			% APPLY TEMPORAL AND FILTER 
			bwF = temporalAndFilter(obj, bwF);
			
		end
		function bwF = findPixelForeground(obj, F, maxExpectedDiameter)
			% Returns potential foreground pixels as logical array			
			if nargin < 3
				maxExpectedDiameter = onGpu(obj, obj.pMaxExpectedDiameter);
			end
			
			% RUN FOR MAX-EXPECTED DIAMETER AND SMALLER POWERS-OF-2
			if maxExpectedDiameter > 8
				dsVec = [2.^(2:nextpow2(maxExpectedDiameter)-1), maxExpectedDiameter];
			else
				dsVec = maxExpectedDiameter;
			end
			if isa(F, 'gpuArray')
				bwF = gpuArray.false(size(F));
			else
				bwF = false(size(F));
			end
			
			% CALL EXTERNAL FUNCTION FOR VARIABLE INPUT
			if isa(F, 'gpuArray')
				% ARRAYFUN ON GPU
				[nRows,nCols,~] = size(F);
				
				% IMMEDIATE NEIGHBORS: SINGLE-PIXEL-SHIFTED ARRAYS (4-CONNECTED)
				Fu = F([1, 1:nRows-1], :, :);
				Fd = F([2:nRows, nRows], :,:);
				Fl = F(:, [1, 1:nCols-1],:);
				Fr = F(:, [2:nCols, nCols], :);
				
				% GENERATE RANDOM NUMBERS FOR SURROUND RANDOMIZATION
				dsRand = round(bsxfun(@minus, bsxfun(@times, dsVec./2, rand(4,length(dsVec),'like',dsVec)), dsVec./4));
				
				% SPACED SURROUNDING PIXELS: MULTI-PIXEL-SHIFTED ARRAYS
				for k=1:length(dsVec)
					ds = max(2, dsVec(k) + dsRand(:,k));
					Su = F([gpuArray.ones(1,ds(1)), gpuArray.colon(1,nRows-ds(1))], :, :);
					Sd = F([gpuArray.colon(ds(2)+1,nRows), nRows.*gpuArray.ones(1,ds(2))], :, :);
					Sl = F(:, [gpuArray.ones(1,ds(3)), gpuArray.colon(1,nCols-ds(3))], :);
					Sr = F(:, [gpuArray.colon(ds(4)+1,nCols), nCols.*gpuArray.ones(1,ds(4))], :);
					% 					ds = dsVec(k);
					% 					Su = F([ones(1,ds), 1:nRows-ds], :, :);
					% 					Sd = F([ds+1:nRows, nRows.*ones(1,ds)], :, :);
					% 					Sl = F(:, [ones(1,ds), 1:nCols-ds], :);
					% 					Sr = F(:, [ds+1:nCols, nCols.*ones(1,ds)], :);
					bwF = bwF | arrayfun(@findPixelForegroundElementWise, F, Fu, Fr, Fd, Fl, Su, Sr, Sd, Sl);
				end
			else
				% VECTORIZED OPS ON CPU OR GPU
				for k=1:length(dsVec)
					bwF = bwF | findPixelForegroundArrayWise(F,dsVec(k));
				end
			end
			% TODO: Benchmark, arraywise versus elementwise function ARRAYFUN (ELEMENTWISE) BENCHMARK
			% (gpu):
			%			1.0000    0.1109 2.0000    0.0057 4.0000    0.0057 8.0000    0.0057 16.0000   0.0057
			%			32.0000   0.0380
			% VECTORIZED (ARRAYWISE) BENCHMARK (gpu):
			% 		1.0000    0.1668
			%     2.0000    0.0228 4.0000    0.0163 8.0000    0.0170
			%    16.0000    0.1303 32.0000    0.2430
			% VECTORIZED (ARRAYWISE) BENCHMARK (cpu):
			% 		1.0000    0.3133
			%     2.0000    0.5230 4.0000    1.0212 8.0000    2.0502
			%    16.0000    4.1064 32.0000    8.9179
		end
		function bwF = temporalRecurrenceFilter(obj, bwF, numPastFrames)
			persistent use_low_gpu_mem_method
			
			% RETRIEVE FROM BUFFER & APPLY TEMPORAL FILTER IF SPECIFIED
			if nargin < 3
				numPastFrames = obj.pRecurrenceFilterNumFrames;
			end
			if isempty(numPastFrames) || numPastFrames < 1
				return
			end
			
			% LOCAL VARIABLES
			[nRows, nCols, N] = size(bwF);
			
			% FILL OR REPLACE INPUT BUFFERED
			bwBufferedFrames = cat(3, obj.RecurrenceFilterInputBuffer, bwF);
			m = size(bwBufferedFrames,3);
			nextBufIdx = (m-numPastFrames+1):m;
			if any(nextBufIdx < 1)
				nextBufIdx(nextBufIdx<1) = 1 - nextBufIdx(nextBufIdx<1);
				if any(nextBufIdx > m)
					nextBufIdx(nextBufIdx>m) = m;
				end
			end
			if isempty(obj.RecurrenceFilterInputBuffer)
				obj.RecurrenceFilterInputBuffer = bwBufferedFrames(:,:,nextBufIdx);
			else
				obj.RecurrenceFilterInputBuffer(:,:,1:numPastFrames) = bwBufferedFrames(:,:,nextBufIdx); % end-nPastFrames+1:end
			end
			
			% CHECK MEMORY AVAILABILITY ON GPU FOR UNVECTORIZED (SLOWER?) COMPUTATION (IF APPLICABLE)
			if isempty(use_low_gpu_mem_method)
				use_low_gpu_mem_method = false;
				if obj.UseGpu
					gpudev = obj.GpuDevice;
					if ~isempty(gpudev) && (gpudev.AvailableMemory < nRows*nCols*N*numPastFrames*2)
						use_low_gpu_mem_method = true;
					end
				end									
			end
			
			if use_low_gpu_mem_method
				% THIS WAY OF COMPUTING MAY WILL NOT OVERWHELM GRAPHICS CARD MEMORY
				bwFout = false(size(bwF),'like',bwF);
				for k=1:numPastFrames
					bwTemp = bwF & bwBufferedFrames(:,:,k+(1:N));
					bwFout = bwFout | bwTemp;
				end
				bwF = bwFout;
			else
				% INDEXED EXPANSION TO PAST FRAMES IN LOGICAL FILTERING OP
				idx = bsxfun(@plus, [0:N-1]', 1:numPastFrames);
				
				% ANY PIXEL MATCHES BETWEEN CURRENT FRAME & PREVIOUS FRAMES ARE USED IN FOREGROUND
				bwF = squeeze(any(...
					bsxfun(@and,...
					bwBufferedFrames(:,:,idx(:,end)+1),...
					reshape(bwBufferedFrames(:,:,idx(:)), nRows, nCols, N, numPastFrames)),...
					4));
			end
				
		end
		function bwF = temporalOrFilter(obj, bwF, numPastFrames)
			persistent use_low_gpu_mem_method
			
			% RETRIEVE FROM BUFFER & APPLY TEMPORAL FILTER IF SPECIFIED
			if nargin < 3
				numPastFrames = obj.pOrFilterNumFrames;
			end
			if isempty(numPastFrames) || numPastFrames < 1
				return
			end
			
			% LOCAL VARIABLES
			[nRows, nCols, N] = size(bwF);
			
			% FILL OR REPLACE INPUT BUFFERED
			bwBufferedFrames = cat(3, obj.OrFilterInputBuffer, bwF);
			m = size(bwBufferedFrames,3);
			nextBufIdx = (m-numPastFrames+1):m;
			if any(nextBufIdx < 1)
				nextBufIdx(nextBufIdx<1) = 1 - nextBufIdx(nextBufIdx<1);
				if any(nextBufIdx > m)
					nextBufIdx(nextBufIdx>m) = m;
				end
			end
			if isempty(obj.OrFilterInputBuffer)
				obj.OrFilterInputBuffer = bwBufferedFrames(:,:,nextBufIdx);
			else
				obj.OrFilterInputBuffer(:,:,1:numPastFrames) = bwBufferedFrames(:,:,nextBufIdx); % end-nPastFrames+1:end
			end
			
			% CHECK MEMORY AVAILABILITY ON GPU FOR UNVECTORIZED (SLOWER?) COMPUTATION (IF APPLICABLE)
			if isempty(use_low_gpu_mem_method)
				use_low_gpu_mem_method = false;
				if obj.UseGpu
					gpudev = obj.GpuDevice;
					if ~isempty(gpudev) && (gpudev.AvailableMemory < nRows*nCols*N*numPastFrames*2)
						use_low_gpu_mem_method = true;
					end
				end									
			end
			
			if use_low_gpu_mem_method
				% THIS WAY OF COMPUTING MAY WILL NOT OVERWHELM GRAPHICS CARD MEMORY				
				for k=1:numPastFrames
					bwF = bwF | bwBufferedFrames(:,:,k+(1:N));					
				end
			else
				% INDEXED EXPANSION TO PAST FRAMES IN LOGICAL FILTERING OP
				idx = bsxfun(@plus, [0:N-1]', 1:numPastFrames);
				
				% ANY PIXEL MATCHES BETWEEN CURRENT FRAME & PREVIOUS FRAMES ARE USED IN FOREGROUND
				bwF = squeeze(any(...										
					reshape(bwBufferedFrames(:,:,idx(:)), nRows, nCols, N, numPastFrames),...
					4));
			end
				
		end
		function bwF = temporalAndFilter(obj, bwF, numPastFrames)
			persistent use_low_gpu_mem_method
			
			% RETRIEVE FROM BUFFER & APPLY TEMPORAL FILTER IF SPECIFIED
			if nargin < 3
				numPastFrames = obj.pAndFilterNumFrames;
			end
			if isempty(numPastFrames) || numPastFrames < 1
				return
			end
			
			% LOCAL VARIABLES
			[nRows, nCols, N] = size(bwF);
			
			% FILL OR REPLACE INPUT BUFFERED
			bwBufferedFrames = cat(3, obj.AndFilterInputBuffer, bwF);
			m = size(bwBufferedFrames,3);
			nextBufIdx = (m-numPastFrames+1):m;
			if any(nextBufIdx < 1)
				nextBufIdx(nextBufIdx<1) = 1 - nextBufIdx(nextBufIdx<1);
				if any(nextBufIdx > m)
					nextBufIdx(nextBufIdx>m) = m;
				end
			end
			if isempty(obj.AndFilterInputBuffer)
				obj.AndFilterInputBuffer = bwBufferedFrames(:,:,nextBufIdx);
			else
				obj.AndFilterInputBuffer(:,:,1:numPastFrames) = bwBufferedFrames(:,:,nextBufIdx); % end-nPastFrames+1:end
			end
			
			% CHECK MEMORY AVAILABILITY ON GPU FOR UNVECTORIZED (SLOWER?) COMPUTATION (IF APPLICABLE)
			if isempty(use_low_gpu_mem_method)
				use_low_gpu_mem_method = false;
				if obj.UseGpu
					gpudev = obj.GpuDevice;
					if ~isempty(gpudev) && (gpudev.AvailableMemory < nRows*nCols*N*numPastFrames*2)
						use_low_gpu_mem_method = true;
					end
				end									
			end
			
			if use_low_gpu_mem_method
				% THIS WAY OF COMPUTING MAY WILL NOT OVERWHELM GRAPHICS CARD MEMORY
				for k=1:numPastFrames
					bwF = bwF & bwBufferedFrames(:,:,k+(1:N));
				end
			else
				% INDEXED EXPANSION TO PAST FRAMES IN LOGICAL FILTERING OP
				idx = bsxfun(@plus, [0:N-1]', 1:numPastFrames);
				
				% ANY PIXEL MATCHES BETWEEN CURRENT FRAME & PREVIOUS FRAMES ARE USED IN FOREGROUND
				bwF = squeeze(all(...										
					reshape(bwBufferedFrames(:,:,idx(:)), nRows, nCols, N, numPastFrames),...
					4));
			end
				
		end
	end
	
	% TUNING
	methods (Hidden)
		function tuneInteractive(obj)
			% TODO
			
			% STEP 1: EXPECTED CELL DIAMETER (in pixels) -> findPixelForeground
			kstep = 1;
			obj.TuningStep(1).ParameterName = 'MaxExpectedDiameter';
			x = obj.MaxExpectedDiameter;
			if isempty(x)
				x = round(max(obj.FrameSize)/20);
			end
			obj.TuningStep(kstep).ParameterDomain = [1:x, x+1:10*x];
			obj.TuningStep(kstep).ParameterIdx = ceil(x);
			obj.TuningStep(kstep).Function = @findPixelForeground;
			obj.TuningStep(kstep).CompleteStep = true;
			
			% STEP 2: TEMPORAL RECURRENCE FILTER SPAN
			kstep = 2;
			obj.TuningStep(kstep).ParameterName = 'RecurrenceFilterNumFrames';
			x = obj.RecurrenceFilterNumFrames;
			if isempty(x)
				x = 3;
			end
			maxSpan = min(10*(x+1), size(obj.TuningImageDataSet,3));
			obj.TuningStep(kstep).ParameterDomain = [0:x x+1:maxSpan];
			obj.TuningStep(kstep).ParameterIdx = ceil(x+1);
			obj.TuningStep(kstep).Function = @testRecurrenceFilter;
			obj.TuningStep(kstep).CompleteStep = true;
			
			% STEP 3: TEMPORAL AND FILTER SPAN
			kstep = 3;
			obj.TuningStep(kstep).ParameterName = 'OrFilterNumFrames';
			x = obj.OrFilterNumFrames;
			if isempty(x)
				x = 3;
			end
			maxSpan = min(10*(x+1), size(obj.TuningImageDataSet,3));
			obj.TuningStep(kstep).ParameterDomain = [0:x x+1:maxSpan];
			obj.TuningStep(kstep).ParameterIdx = ceil(x+1);
			obj.TuningStep(kstep).Function = @testOrFilter;
			% 			obj.TuningStep(kstep).Function = @testOrFilter;
			obj.TuningStep(kstep).CompleteStep = true;
			
			% STEP 4: TEMPORAL OR FILTER SPAN
			kstep = 4;
			obj.TuningStep(kstep).ParameterName = 'AndFilterNumFrames';
			x = obj.AndFilterNumFrames;
			if isempty(x)
				x = 3;
			end
			maxSpan = min(10*(x+1), size(obj.TuningImageDataSet,3));
			obj.TuningStep(kstep).ParameterDomain = [0:x x+1:maxSpan];
			obj.TuningStep(kstep).ParameterIdx = ceil(x+1);
			obj.TuningStep(kstep).Function = @testAndFilter;
			% 			obj.TuningStep(kstep).Function = @testAndFilter;
			obj.TuningStep(kstep).CompleteStep = true;
			
			setPrivateProps(obj)
			
			% SET UP TUNING WINDOW
			createTuningFigure(obj);			%TODO: can also use for automated tuning?
			
		end
		function tuneAutomated(obj)
			% TODO
			obj.TuningImageDataSet = [];
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
			obj.RecurrenceFilterInputBuffer = findPixelForeground(obj, gpuArray(obj.TuningImageDataSet(:,:,bufIdx)));
			F = temporalRecurrenceFilter(obj, F, numPastFrames);
			
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
		function F = testOrFilter(obj, F)		
			numPastFrames = obj.OrFilterNumFrames;			
			curIdx = obj.TuningImageIdx;
			bufIdx = max(1, (curIdx-numPastFrames):(curIdx-1));
			obj.OrFilterInputBuffer = temporalRecurrenceFilter(obj, ...
				findPixelForeground(obj, gpuArray(obj.TuningImageDataSet(:,:,bufIdx))));
			F = temporalOrFilter(obj, F, numPastFrames);			
		end	
		function F = testAndFilter(obj, F)
			numPastFrames = obj.AndFilterNumFrames;
			curIdx = obj.TuningImageIdx;
			bufIdx = max(1, (curIdx-numPastFrames):(curIdx-1));
			obj.AndFilterInputBuffer = temporalOrFilter(obj, ...
				temporalRecurrenceFilter(obj, ...
				findPixelForeground(obj, gpuArray(obj.TuningImageDataSet(:,:,bufIdx)))));
			F = temporalAndFilter(obj, F, numPastFrames);
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
	
	
	
end

































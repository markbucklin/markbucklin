classdef (CaseInsensitiveProperties = true) TemporalFilter < scicadelic.SciCaDelicSystem
	% TemporalFilter
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
		WinSpan = 1;		% Number of prior frames to filter with current frame
		FilterType = 'Composite' % 'Recurrence' , 'And' ('All') , 'Or' ('Any')
	end
	
	% STATES
	properties (DiscreteState)		
	end
	
	% BUFFERS
	properties (SetAccess = protected, Hidden)		
		InputBuffer					% Logical array 'WinSpan' frames
	end
	
	% PRIVATE VARIABLES
	properties (SetAccess = protected, Hidden, Nontunable)
		FilterTypeSet = matlab.system.StringSet({'Composite','WinMaxComposite','WinMeanComposite','Difference','WinMeanDifference','WinMaxIdx'})
		FilterTypeIdx
	end
	properties (SetAccess = protected, Hidden, Nontunable)
		pWinSpan
	end
	
	
	
	
	
	
	
	
	
	
	
	% CONSTRUCTOR
	methods
		function obj = TemporalFilter(varargin)
			setProperties(obj,nargin,varargin{:});
			parseConstructorInput(obj,varargin(:));			
			obj.CanUseInteractive = true;
			setPrivateProps(obj);
		end
	end
	
	% BASIC INTERNAL SYSTEM METHODS
	methods (Access = protected)
		function setupImpl(obj, F)
			
			% INITIALIZE
			fillDefaults(obj)			
			checkInput(obj, F);
			obj.TuningImageDataSet = [];			
			setPrivateProps(obj)
						
			% PREALLOCATE BUFFER FOR TEMPORAL FILTER
			Fbuf = F;
			m = obj.WinSpan;
			if m >= 1				
				if m <= size(Fbuf,3)
					obj.InputBuffer = Fbuf(:,:,m:-1:1);
				else
					obj.InputBuffer = repmat(Fbuf(:,:,1), 1, 1, m);
				end				
			end
			
			% SET/LOCK FILTER TYPE 
			updateFilterTypeIdx(obj)
			
			% ASSIGN OUTPUT-DATATYPE
			Fbuf = processData(obj, Fbuf);
			obj.OutputDataType = getClass(obj, Fbuf);
			
			
		end
		function output = stepImpl(obj, data)
			
			% LOCAL VARIABLES
			inputNumFrames = size(data,3);
						
			% CELL-SEGMENTAION PROCESSING ON GPU
			data = onGpu(obj, data);
			output = processData(obj, data);
			
		end
		function releaseImpl(obj)
			fetchPropsFromGpu(obj)
		end
	end
	
	% RUN-TIME HELPER METHODS
	methods (Access = protected)
		function bwF = processData(obj, bwF)
			
			switch obj.FilterTypeIdx				
				
				case 1
					% APPLY TEMPORAL RECURRENCE FILTER TO FOREGROUND
					bwF = temporalRecurrenceFilter(obj, bwF);
					
				case {2,3}
					% APPLY TEMPORAL AND FILTER
					bwF = temporalAndFilter(obj, bwF);
					
				case {4,5}
					% APPLY TEMPORAL OR FILTER
					bwF = temporalOrFilter(obj, bwF);
			end
			
		end		% TODO: pull redundant code out of functions below
		function bwF = temporalRecurrenceFilter(obj, bwF, numPastFrames)
			persistent use_low_gpu_mem_method
			
			% RETRIEVE FROM BUFFER & APPLY TEMPORAL FILTER IF SPECIFIED
			if nargin < 3
				numPastFrames = obj.pWinSpan;
			end
			if isempty(numPastFrames) || numPastFrames < 1
				return
			end
			
			% LOCAL VARIABLES
			[nRows, nCols, N] = size(bwF);
			
			% FILL OR REPLACE INPUT BUFFERED
			bwBufferedFrames = cycleInputBuffer(obj, bwF, numPastFrames);
			
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
				numPastFrames = obj.pWinSpan;
			end
			if isempty(numPastFrames) || numPastFrames < 1
				return
			end
			
			% LOCAL VARIABLES
			[nRows, nCols, N] = size(bwF);
			
			% FILL OR REPLACE INPUT BUFFERED
			bwBufferedFrames = cycleInputBuffer(obj, bwF, numPastFrames);
			
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
				numPastFrames = obj.pWinSpan;
			end
			if isempty(numPastFrames) || numPastFrames < 1
				return
			end
			
			% LOCAL VARIABLES
			[nRows, nCols, N] = size(bwF);
			
			% FILL OR REPLACE INPUT BUFFERED
			bwBufferedFrames = cycleInputBuffer(obj, bwF, numPastFrames);
			
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
		function Fbuf = cycleInputBuffer(obj, F, numPastFrames)
			Fbuf = cat(3, obj.InputBuffer, F);
			m = size(Fbuf,3);
			nextBufIdx = (m-numPastFrames+1):m;
			if any(nextBufIdx < 1)
				nextBufIdx(nextBufIdx<1) = 1 - nextBufIdx(nextBufIdx<1);
				if any(nextBufIdx > m)
					nextBufIdx(nextBufIdx>m) = m;
				end
			end
			if isempty(obj.InputBuffer)
				obj.InputBuffer = Fbuf(:,:,nextBufIdx);
			else
				obj.InputBuffer(:,:,1:numPastFrames) = Fbuf(:,:,nextBufIdx); % end-nPastFrames+1:end
			end
		end
	end
	
	% TUNING
	methods (Hidden)
		function varargout = tuneInteractive(obj)
			% TODO
			
			% STEP 1: EXPECTED CELL DIAMETER (in pixels) -> findPixelForeground
			kstep = 1;
			filterTypes = {'Recurrence','And','Or'};
			currentFilterType = obj.FilterType;
			if isempty(currentFilterType)
				currentFilterType = filterTypes{1};
			end
			obj.TuningStep(1).ParameterName = 'FilterType';			
			obj.TuningStep(kstep).ParameterDomain = filterTypes;
			obj.TuningStep(kstep).ParameterIdx = find(~cellfun('isempty',strfind(filterTypes, currentFilterType)));
			obj.TuningStep(kstep).Function = @testFilterType;
			obj.TuningStep(kstep).CompleteStep = false;
			
			% STEP 2: TEMPORAL FILTER SPAN (NUMBER OF FRAMES)
			kstep = 2;
			obj.TuningStep(kstep).ParameterName = 'WinSpan';
			x = obj.WinSpan;
			if isempty(x)
				x = 3;
			end
			maxSpan = min(10*(x+1), size(obj.TuningImageDataSet,3));
			obj.TuningStep(kstep).ParameterDomain = [0:x x+1:maxSpan];
			obj.TuningStep(kstep).ParameterIdx = ceil(x+1);
			obj.TuningStep(kstep).Function = @testTemporalFilter;
			obj.TuningStep(kstep).CompleteStep = true;
			
			% SET UP TUNING WINDOW (OR RETURN TUNING STEPS FOR PARENT SYSTEM TO CALL)
			setPrivateProps(obj)
			if nargout
				varargout{1} = obj.TuningStep;
			else
				createTuningFigure(obj);			%TODO: can also use for automated tuning?
			end
			
		end
		function tuneAutomated(obj)
			% TODO
			obj.TuningImageDataSet = [];
		end
		function bwF = testFilterType(obj, bwF)
			updateFilterTypeIdx(obj)
			% 			bwF = processData(obj, bwF);
		end
		function bwF = testTemporalFilter(obj, bwF)
			numPastFrames = obj.WinSpan;
			curIdx = obj.TuningImageIdx;
			bufIdx = max(1, (curIdx-numPastFrames):(curIdx-1));
			obj.InputBuffer = onGpu(obj, obj.TuningImageDataSet(:,:,bufIdx));
			bwF = processData(obj, bwF);
			% 			bwF = processData(obj, onGpu(obj, bwF));
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
		function updateFilterTypeIdx(obj)
			% SET/LOCK FILTER TYPE 
			if ~isempty(obj.FilterType)
				obj.FilterTypeIdx = getIndex(obj.FilterTypeSet, obj.FilterType);
			else
				obj.FilterTypeIdx = 1;
			end
		end
	end
	methods
		function set.FilterType(obj, filterType)			
			obj.FilterType = filterType;
			updateFilterTypeIdx(obj);
		end
	end
	
	
end

































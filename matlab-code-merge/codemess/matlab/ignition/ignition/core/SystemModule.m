classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		Module < ignition.core.Object & matlab.System
	%
	% Equivalent to gstreamer element?
	% ---------------->>>>> in progress
	%
	%
	
	
	% ##################################################
	% SETTINGS
	% ##################################################
	properties (SetAccess = immutable)
		Name = ''
	end
	properties (Logical)
		Enabled = true % todo
	end
	properties (Access = public, Logical, Nontunable)
		UseGpu
		UseParallel
		UseBuffer
		UseInteractive
	end
	properties (Access = public)
		PreferredGpuNum % todo: make static or global?
	end
	
	% ##################################################
	% INPUT/OUTPUT PORTS & CHARACTERISTICS
	% ##################################################
	properties
		StreamInput
		StreamOutput
	end
	properties (SetAccess = ?ignition.core.Object)
		NumFramesInputCount = 0
		NumFramesOutputCount = 0
	end
	properties (SetAccess = ?ignition.core.Object, Nontunable)		
		InputList
		InputDataType		
		InputPortProps
		NumInputPorts
		NumInputs
		OutputList
		OutputDataType
		OutputPortProps
		NumOutputPorts
		NumOutputs
	end
	properties (SetAccess = ?ignition.core.Object, Nontunable)
		InitializeFcn
		InputTransferFcn
		InputConversionFcn
		RunFcn
		OutputConversionFcn
		OutputTransferFcn
	end
	properties (SetAccess = ?ignition.core.Object, Nontunable)
		FrameSize
		FrameDimension = 4
		MaxFramesPerStep = 32
	end
	
	% COMPUTER CAPABILITIES & DEFAULTS (ENVIRONMENT)
	properties (SetAccess = ?ignition.core.Object, Nontunable)
		PerformanceMonitorObj
	end
	properties (SetAccess = ?ignition.core.Object)
		BenchTick
	end
	properties (SetAccess = ?ignition.core.Object, Transient)
		StatusMonitorObj
		GlobalContextObj
	end
	
	% STATUS
	properties (SetAccess = ?ignition.core.Object, Transient)
		IsInitialized @logical scalar = false
	end
	
	% ##################################################
	% EVENTS
	% ##################################################
	events (NotifyAccess = ?ignition.core.Object)
		Initializing
		Ready
		InputDataAvailable
		Processing
		OutputDataAvailable
		Finished
		Error
	end
	
	% ##################################################
	% CONSTRUCTOR
	% ##################################################
	methods
		function obj = Module(varargin)
			
			fprintf('Module: Constructor\n')
			
			% COPY FROM SUB-OBJECT INPUT IF CLONING?? (todo)
			if nargin
				if isa(varargin{1}, 'ignition.core.Module')
					obj = copyProps(obj, varargin{1});
				else
					parseConstructorInput(obj,varargin{:})
				end
			end
			% 			if nargin && isa(varargin{1}, 'ignition.core.Module')
			% 				obj = copyProps(obj, varargin{1});
			% 			end
			
			% INITIALIZE DEFAULT ENVIRONMENT
			obj.GlobalContextObj = ignition.core.GlobalContext;
			ctxt = obj.GlobalContextObj;
			defaultfalse = @(b) ~isempty(b) && logical(b);
			obj.UseGpu = (defaultfalse(obj.UseGpu) | ctxt.UseGpuPreference) & (ctxt.CanUseGpu);
			obj.UseParallel = (defaultfalse(obj.UseParallel) | ctxt.UseParallelPreference) & ctxt.CanUseParallel;
			obj.UseBuffer = (defaultfalse(obj.UseBuffer) | ctxt.UseBufferPreference) & ctxt.CanUseBuffer;
			obj.UseInteractive = (defaultfalse(obj.UseInteractive) | ctxt.UseInteractivePreference) & ctxt.CanUseInteractive;
			
			
			% PRE/POST-INITIALIZATION LISTENERS
			% 			constructEventListeners(obj)
			
			% BENCHMARKING OBJECT
			if isempty(obj.PerformanceMonitorObj) || ~isvalid(obj.PerformanceMonitorObj)
				obj.PerformanceMonitorObj = ignition.core.PerformanceMonitor();
			end
			
			% STATUS MONITOR
			obj.StatusMonitorObj = ignition.core.StatusMonitor(obj);
			
			% PARSE INPUT
			% 			if nargin
			% 				parseConstructorInput(obj,varargin(:))
			% 			end
			
		end
		
		function delete(obj)
			try
				delete(obj.GlobalContextObj)
			catch
			end
		end
	end
	
	% ##################################################
	% INITIALIZATION HELPER METHODS
	% ##################################################	
	methods (Access = ?ignition.core.Object)
		function preInitialize(obj, ~) %streamIn
			% Called by subclasses during setupImpl() Performs common/shared initialization tasks.
			% (currently the only task is calling connect(obj.GlobalContextObj))
				
			% FIRE EVENT -> INITIALIZING
			notify(obj, 'Initializing')
			
			
			if obj.IsInitialized
				% FIRE EVENT -> READY
				notify(obj, 'Ready')
				return
			end						
			
			% TRIGGER GPU DEVICE SELECTION & PARALLEL POOL CREATION
			if obj.UseGpu || obj.UseParallel
				connect(obj.GlobalContextObj)
			end						
			
		end
		function postInitialize(obj, ~)
			
			obj.IsInitialized = true;			
			
			% FIRE EVENT -> READY
			notify(obj, 'Ready')
		end
		function streamIn = preRun(obj, streamIn)
			
			% FIRE EVENT -> PROCESSING
			notify(obj, 'Processing')
			obj.BenchTick = tic;
			
			% GET NUMBER OF FRAMES IN INPUT
			numFrames = ignition.shared.getNumFrames(streamIn);
			
			% UPDATE FRAME INPUT COUNTER (PREINCREMENTED)
			obj.NumFramesInputCount = obj.NumFramesInputCount + numFrames;
			
			% INPUT TRANSFER FUNCTION
			xferFcn = obj.InputTransferFcn;
			if ~isempty(xferFcn)
				streamIn = xferFcn(streamIn);
			end
			
			% INPUT CONVERSION FUNCTION
			conversionFcn = obj.InputConversionFcn;
			if ~isempty(conversionFcn)
				streamIn = conversionFcn(streamIn);
			end
			
		end
		function streamOut = postRun(obj, streamOut)
			
			% GET NUMBER OF FRAMES IN OUTPUT
			numFrames = ignition.shared.getNumFrames(streamOut);
			
			% UPDATE FRAME OUTPUT COUNTER (POSTINCREMENTED)
			obj.NumFramesOutputCount = obj.NumFramesOutputCount + numFrames;
			
			% OUTPUT TRANSFER FUNCTION
			xferFcn = obj.OutputTransferFcn;
			if ~isempty(xferFcn)
				streamOut = xferFcn(streamOut);
			end
			
			% OUTPUT CONVERSION FUNCTION
			conversionFcn = obj.OutputConversionFcn;
			if ~isempty(conversionFcn)
				streamOut = conversionFcn(streamOut);
			end			
			
			% ADD BENCHMARK
			addBenchmark(obj.PerformanceMonitorObj, toc(obj.BenchTick), numFrames);						
			
			% FIRE EVENT -> OUTPUTDATAAVAILABLE & READY
			notify(obj, 'OutputDataAvailable');%TODO: add event.eventData
			notify(obj, 'Ready')
			
		end		
	end
	methods (Access = protected)
		function setupImpl(obj, varargin)
						
				try					
					if obj.Enabled
						if nargin > 1
							streamIn = varargin{1};
							
							preInitialize(obj, streamIn);
							
							initialize(obj, streamIn);
							
							postInitialize(obj, streamIn);
						else
							preInitialize(obj);
							
							initialize(obj);
							
							postInitialize(obj);
							
						end						
					end
				catch me
					handleError(obj, me)
				end
			
		end
		function streamOut = stepImpl(obj, streamIn)
			
			try
				if nargin < 2
					streamIn = [];
				end
				if obj.Enabled
					streamIn = preRun(obj, streamIn);					
					if ~isempty(streamIn)
						streamOut = run(obj, streamIn);
					else
						streamOut = run(obj);
					end
					streamOut = postRun(obj, streamOut);
					
				else
					streamOut = streamIn;
					
				end
			catch me
				handleError(obj, me)
			end
			
		end
		function validateInputsImpl(obj, varargin)
			
			% CHECK FOR EMPTY INPUT & EXPECT FIRST ARGUMENT IS VIDEO SEGMENT DATA
			if nargin
				if ~isempty(varargin)
					streamIn = varargin{1};
				else
					return
				end
			else
				return
			end
			
			% INPUT DATA-TYPE
			obj.InputDataType = ignition.shared.getDataType(streamIn);
			
			% CHECK IF INPUT IS ALREADY ON GPU
			if isempty(obj.UseGpu)
				obj.UseGpu = isOnGpu(streamIn);
			end
			
			% CHECK IF INPUT NEEDS TRANSFER TO GPU
			
			% INPUT DATA SIZE/DIMENSIONS
			[numRows,numCols,numChannels] = getFrameSize(streamIn);
			obj.FrameSize = [numRows,numCols,numChannels];
			
			% GET NUMBER OF FRAMES IN INPUT -> MAX FRAMES-PER-STEP
			% 			numFrames = ignition.shared.getNumFrames(F);
			% 			obj.MaxFramesPerStep = ignition.shared.initOrUpdate(...
			%					@max, obj.MaxFramesPerStep, numFrames);
									
		end
		function numInputs = getNumInputsImpl(obj)
			% Returns the number of '__InputPort' properties set to true -> max number of i returned
			
			if isLocked(obj)
				numInputs = obj.NumInputs;
				
			else
				numInputs = 0;
				if isempty(obj.NumInputPorts) || isempty(obj.InputPortProps)
					mobj = metaclass(obj);
					mprop = mobj.PropertyList;
					propNames = {mprop.Name};
					isPortProp = ~cellfun(@isempty, regexp(propNames, '(\w*)InputPort\>') );
					obj.InputPortProps = mprop(isPortProp);
					obj.NumInputPorts = nnz(isPortProp);
				end
				allPortProps = {obj.InputPortProps(:).Name};				
				k = 0;
				while (k < numel(allPortProps))
					k = k + 1;
					if obj.(allPortProps{k})
						numInputs = numInputs + 1;
					end
				end
				obj.NumInputs = numInputs;
				
				% TODO: P = matlab.mixin.util.PropertyGroup(PROPERTYLIST, TITLE)
				
			end
			
		end
		function numOutputs = getNumOutputsImpl(obj)
			% Returns the number of '__OutputPort' properties set to true -> max number of outputs returned
			
			if isLocked(obj)
				numOutputs = obj.NumOutputs;
				
			else
				numOutputs = 0;
				if isempty(obj.NumOutputPorts) || isempty(obj.OutputPortProps)
					mobj = metaclass(obj);
					mprop = mobj.PropertyList;
					propNames = {mprop.Name};
					isPortProp = ~cellfun(@isempty, regexp(propNames, '(\w*)OutputPort\>') );
					obj.OutputPortProps = mprop(isPortProp);
					obj.NumOutputPorts = nnz(isPortProp);
				end
				allPortProps = {obj.OutputPortProps(:).Name};				
				k = 0;
				while (k < numel(allPortProps))
					k = k + 1;
					if obj.(allPortProps{k})
						numOutputs = numOutputs + 1;
					end
				end
				obj.NumOutputs = numOutputs;
			end
			
		end
	end
	methods
		function initialize(obj)
			
			initFcn = obj.InitializeFcn;
			if ~isempty(initFcn)
				initFcn()
			end
			
		end
		function streamOut = run(obj, streamIn)
			if nargin < 2
				streamIn = [];
			end
			runFcn = obj.RunFcn;
			if ~isempty(runFcn)
				if ~isempty(streamIn)
					streamOut = runFcn(streamIn);
				else
					streamOut = runFcn();
				end
			else
				streamOut = streamIn;
			end
		end		
	end	
	
	% TODO METHODS: IMPLEMENT ALL
	methods (Access = protected)
		function me = handleError(obj, me)
			% 			try setStatus(obj, [], 'error'), catch, end
			notify(obj, 'Error')
			rethrow(me); %TODO
		end
	end
	
	
	
	
end











% 
% 	properties (SetAccess = ?ignition.core.Object, Hidden, Transient)
% 		PreInitListener
% 		PostInitListener
% 	end
% 
% 
% methods (Hidden)
% 		function constructEventListeners(obj)
% obj.PreInitListener = event.listener(obj,...
%		'Initializing', @(src,evnt)preInitialize(obj));
% obj.PostInitListener = event.listener(obj,...
%		'Ready', @(src,evnt)postInitialize(obj));			
% 		end
% 	end










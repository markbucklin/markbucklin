classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		Task < ignition.core.Object & handle
	%Task Reference to properties of current computational environment
	%   TODO:Details
	
	
	
	
	% SETTINGS
	properties (SetAccess = immutable)
		Name = ''
	end
	properties
		Priority = 0
	end
	properties
		Enabled @logical scalar = true % todo
	end
	
	% FUNCTION HANDLES
	properties (SetAccess = protected)
		ConfigurationFunction @function_handle
		InitializationFunction @function_handle
		DataAvailableFunction @function_handle
		Function @function_handle
		DataWrittenFunction @function_handle
		FinalizationFunction @function_handle
		ErrorFunction @function_handle
	end
	properties 
		CheckInputFcn
		ExecuteFcn
		DataAvailableFcn
		RunTaskFcn
		PostExecutionFcn
		ExecutionFinishedFcn
		PeriodicTaskFcn
		PeriodicCheckFcn
		SynchronousTaskFcn
		FetchResultFcn
		FetchOutputFcn
		
		ExecutionErrorFcn
		InputEmptyFcn
	end
	
	% INPUT/OUTPUT
	properties (SetAccess = protected)				
		
		TaskConfiguration @struct		
		TaskStorage @struct % TaskData InitData
		
		InputArguments @cell
		OutputArguments @cell
		
		NumInputArguments = 0
		NumOutputArguments = 0
		
		InputCache
		OutputCache
		
		TunableConfig
		DynamicConfig
		LockedConfig
		
		PersistentExecutionDependency		
		StoredTaskData
		PersistentData
		SynchronousTaskInput
		
		
		
		
		IsTaskConfigInput @logical
		IsTaskStorageInput @logical
		IsTaskStorageOutput @logical %todo
		
		
		StreamInputBuffer @ignition.core.Buffer
		StreamOutputBuffer @ignition.core.Buffer		
	end
	
	% STATUS
	properties (SetAccess = ?ignition.core.Object, Transient)
		%'pending','queued','running','finished','failed','unavailable'.
		State @struct %todo
		IsConfigured @logical scalar = false
		IsInitialized @logical scalar = false
		IsFinished @logical scalar = false
		ErrorOutput %todo
	end
	
	% COMPUTER CAPABILITIES & DEFAULTS (ENVIRONMENT)
	properties (SetAccess = ?ignition.core.Object)
		PerformanceMonitorObj
	end
	properties (SetAccess = ?ignition.core.Object)
		BenchTick
	end
	properties (SetAccess = ?ignition.core.Object, Transient)
		StatusMonitorObj
		GlobalContextObj
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
	% USER CALLABLE METHODS
	% ##################################################	
	methods
		function obj = Task( taskFcnHandle, numArgsOut, varargin)
			
			% ASSIGN INPUT ARGUMENTS TO PROPERTIES (IF PROVIDED)
			if (nargin > 0)
				obj.Function = taskFcnHandle;
				if (nargin > 1)
					obj.NumOutputArguments = numArgsOut;
				end
			end
			
			
		end
		function configure(obj, taskFcnHandle, numArgsOut, varargin)
			%		>> schedule(obj, taskFcnHandle, numArgsOut, varargin{:})
			%		>> schedule(obj)
			if nargin < 4
				taskInput = obj.InputArguments;
			else
				taskInput = varargin;
			end
			if (nargin < 3)
				numArgsOut = obj.NumOutputArguments;
				if (nargin < 2)
					taskFcnHandle = obj.Function;
				end
			end
			
			obj.InputArguments = taskInput;
			obj.NumOutputArguments = numArgsOut;
			obj.Function = taskFcnHandle;
			
			obj.IsConfigured = true;
			
		end
		function initialize(obj, varargin)									
			% INITIALIZE TASK DATA	
			
				try	
					if nargin > 1
							obj.InputArguments = varargin;
					end
					
					if obj.Enabled
						% GET INITIALIZATION FUNCTION HANDLE
						initFcn = obj.InitializationFunction;
						
						% CHECK IF OBJECT IS CONFIGURED
						if ~obj.IsConfigured
							configure(obj)
						end
						
						% GET TASK CONFIGURATION
						taskConfig = obj.TaskConfiguration;
						
						% GET TASK DATA
						taskInput = obj.InputArguments;
						
						% CONSTRUCT INITIALIZATION FUNCTION ARGUMENTS																		
						initArgs = [taskInput, {taskConfig}];
						
						prePostInitArgs = {obj, initArgs{:} };
						
						preInitialize(obj, prePostInitArgs);
												
						obj.TaskStorage = feval(initFcn, initArgs{:});% todo -> parfeval
						% 						[obj.TaskConfiguration, obj.TaskStorage] = ...
						% 							feval(initFcn, initArgs{:});% todo -> parfeval
						
						postInitialize(obj, prePostInitArgs);
						
					end
				catch me
					handleError(obj, me)
				end
			
		end
		function execute(obj, varargin)
			try				
				if obj.Enabled
					if nargin > 1
						obj.InputArguments = varargin;
					end
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
		function delete(obj)
			try
				notify(obj, 'Finished')
			catch
			end
		end
	end
	
	% ##################################################
	% INITIALIZATION & EXECUTION PRE/POST HELPER METHODS
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
			
			% INITIALIZE COMMON FRAME-COUNTER IN TASK-DATA
			obj.TaskStorage.NumFramesInputCount = 0;
			obj.TaskStorage.NumFramesOutputCount = 0;
			
			% SET INITIALIZED STATE FLAG
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
			obj.TaskStorage.NumFramesInputCount = obj.TaskStorage.NumFramesInputCount + numFrames;			
			
		end
		function streamOut = postRun(obj, streamOut)
			
			% GET NUMBER OF FRAMES IN OUTPUT
			numFrames = ignition.shared.getNumFrames(streamOut);
			
			% UPDATE FRAME OUTPUT COUNTER (POSTINCREMENTED)
			obj.TaskStorage.NumFramesOutputCount = obj.TaskStorage.NumFramesOutputCount + numFrames;
									
			% ADD BENCHMARK
			addBenchmark(obj.PerformanceMonitorObj, toc(obj.BenchTick), numFrames);						
			
			% FIRE EVENT -> OUTPUTDATAAVAILABLE & READY
			notify(obj, 'OutputDataAvailable');%TODO: add event.eventData
			notify(obj, 'Ready')
			
		end		
	end
	
	methods (Hidden)
		function setTaskOutput(obj, taskOutput)
			obj.OutputArguments = taskOutput;
		end
	end
	methods (Access = protected)		
		function me = handleError(obj, me)
			% 		function logTaskError(~,src,evnt)
			% todo
			fprintf('An error occurred : src,evnt sent to base workspace\n')
			assignin('base','src',src);
			assignin('base','evnt',evnt);
			notify(obj, 'Error')
			rethrow(me); %TODO
		end
	end
	
	
	
	
	
	
end
















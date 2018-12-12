classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		Task < ignition.core.Object & handle & matlab.mixin.CustomDisplay
	%Task Reference to properties of current computational environment
	%   TODO:Details
	
	
	
	
	% TASK CONTROL
	properties		
		Priority = 0
		Enabled @logical scalar = true % todo
		DispatchMethod @ignition.core.FunctionDispatchType
	end
	
	% TASK CONFIGURATION
	properties (SetAccess = protected)
		Name = ''
		ConfigureTaskFcn @function_handle		
		ConfigurationInputProperties @cell
		InitializeTaskFcn @function_handle
		IsConfigInput @logical
		IsInitDataInput @logical		
	end
	
	% TASK FUNCTION
	properties (SetAccess = protected)
		PreMainTaskFcn @function_handle
		MainTaskFcn @function_handle
		PostMainTaskFcn @function_handle
		FinalizeTaskFcn @function_handle
		ErrorFcn @function_handle
	end
	
	% INPUT/OUTPUT DESCRIPTION
	properties (SetAccess = protected)			
		Configuration @struct
		Cache @struct
		InputArguments @cell
		OutputArguments @cell
		NumInputArguments = 0
		NumOutputArguments = 0
		InputArgumentNames @cell
		OutputArgmentNames @cell
	end
	
	% I/O CACHE SIZES & FRAME-DELAYS
	properties (SetAccess = protected)
		InputCacheMaxSize = 0
		OutputCacheMaxSize = 0
		TrainTaskDataDelay = 0
		SynchronousFrameDelay = 0
	end
	
	% PERSISTENT INPUT/OUTPUT ARGUMENTS
	properties (SetAccess = protected)	
		InputCache @cell		
		OutputCache @cell
	end
	
	
	
	% STATUS
	properties (SetAccess = ?ignition.core.Object, Transient)		
		State @ignition.core.TaskState
		IsConfigured @logical scalar = false
		IsInitialized @logical scalar = false
		IsFinished @logical scalar = false
		IsFinalized @logical scalar = false		
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
		DispatchFutureObj
		DispatchOutput
		PropertyGroupObj @matlab.mixin.util.PropertyGroup
	end
	
	
	
	
	% ##################################################
	% EVENTS
	% ##################################################
	events (NotifyAccess = ?ignition.core.Object)		
		Ready
		Processing
		Finished
		Error
	end
	
	
	
	% ##################################################
	% USER CALLABLE METHODS
	% ##################################################	
	methods
		function obj = Task( taskFcnHandle, numArgsOut, varargin)
			
			% SET ANY INITIAL PROPERTIES
			obj.State = ignition.core.TaskState.PreConfigure;
			
			% ASSIGN INPUT ARGUMENTS TO PROPERTIES (IF PROVIDED)
			if (nargin > 0)
				obj.MainTaskFcn = taskFcnHandle;
				if (nargin > 1)
					obj.NumOutputArguments = numArgsOut;
					if (nargin > 2)
						obj.NumInputArguments = numel(varargin);
						% todo -> InputArgumentNames , OutputArgmentNames
					end
				end
			end
			
			
			% todo -> move to TaskExecutor??
			
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
		function configure(obj)%, taskFcnHandle, numArgsOut, varargin)			
			
			% todo
			
			obj.State = ignition.core.TaskState.Configuring;
			
			% 			if nargin < 4
			% 				taskInput = obj.InputArguments;
			% 			else
			% 				taskInput = varargin;
			% 			end
			% 			if (nargin < 3)
			% 				numArgsOut = obj.NumOutputArguments;
			% 				if (nargin < 2)
			% 					taskFcnHandle = obj.MainTaskFcn;
			% 				end
			% 			end
			
			% CONFIGURE TASK FUNCTION
			if ~isempty(obj.ConfigureTaskFcn)
				if ~isempty(obj.ConfigurationInputProperties)
					for k=1:numel(obj.ConfigurationInputProperties)
						prop = obj.ConfigurationInputProperties{k};
						argsIn{k} = obj.(prop);
					end
					obj.Configuration = feval( obj.ConfigureTaskFcn, argsIn{:});
					
				else
					obj.Configuration = feval( obj.ConfigureTaskFcn);
					
				end
			end
			
			% UPDATE TASK CONFIGURATION/DEFINITION PROPERTIES (todo)
			fillPropsFromStruct(obj, obj.Configuration);
			% 			obj.InputArguments = taskInput;
			% 			obj.NumOutputArguments = numArgsOut;
			% 			obj.MainTaskFcn = taskFcnHandle;
			
			% UPDATE TASK STATE PROPERTIES
			obj.IsConfigured = true;
			obj.IsInitialized = false;
			obj.State = ignition.core.TaskState.PreInit;
			
		end
		function initialize(obj, varargin)									
			% INITIALIZE TASK DATA	
			
			if nargin > 1
							obj.InputArguments = varargin;
			end
					
				try						
					if obj.Enabled
						
						% COMMON PRE-INITIALIZE-TASK FUNCTION
						preInitialize(obj);
						
						% CUSTOM INITIALIZE-TASK FUNCTION
						initFcn = obj.InitializeTaskFcn;
						initArgs = [{obj.Configuration}, obj.InputArguments];
						[obj.Configuration, obj.Cache] = feval(initFcn, initArgs{:});						
						
						% COMMON POST-INITIALIZE-TASK FUNCTION
						postInitialize(obj);
												
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
					
					argsIn = obj.InputArguments;
					numIn = obj.NumInputArguments;
					numOut = obj.NumOutputArguments;
					
					% PRE-EXECUTITION METHOD
					if numIn > 0
						streamIn = argsIn{1};					
						streamIn = preExecute(obj, streamIn);
						if numIn > 1
							argsIn = { streamIn , argsIn{2:end} };
						end
					end
					% todo -> PreMainTaskFcn
					
					% EXECUTE USING DISPATCH METHOD
					% todo -> config , taskCache
					dispatch(obj, obj.MainTaskFcn, numOut, argsIn{:});
					
					% POST-EXECUTION METHOD
					% todo -> wait?					
					obj.OutputArguments = postExecute(obj, obj.OutputArguments);
					
				else
					% DIRECT PASS-THROUGH WITH NO PROCESSING ??
					obj.OutputArguments = obj.InputArguments;
					
				end
			catch me
				handleError(obj, me)
			end
		end
		function finalize(obj)
			if ~isempty(obj.FinalizeTaskFcn)
				dispatch(obj, obj.FinalizeTaskFcn, 0, obj)
				% todo -> just use feval(obj.FinalizeTaskFcn, obj)				
				setFinalized();									
			end
			
			%todo
			function setFinalized()
				obj.State = ignition.core.TaskState.Finished;
				obj.IsFinalized = true;												
			end			
		end
		function delete(obj)
			try
				if ~obj.IsFinalized && ~isempty(obj.FinalizeTaskFcn)
					% 					dispatch(obj, obj.FinalizeTaskFcn, 0)
					feval(obj.FinalizeTaskFcn, obj);
					obj.State = igniition.core.TaskState.Finished;
				end
			catch
			end
		end
	end
	
	% ##################################################
	% INITIALIZATION & EXECUTION PRE/POST HELPER METHODS
	% ##################################################	
	methods (Access = ?ignition.core.Object)
		function dispatch(obj, fcn, numOut, varargin)
			
			if nargin < 4
				args = {obj};
			else
				args = varargin;
			end
			if nargin < 3
				numOut = 0;
			end
			
			import ignition.core.FunctionDispatchType
			
			switch obj.DispatchMethod
				case FunctionDispatchType.Synchronous
					% STANDARD-SYNCHRONOUS
					if numOut > 0
						obj.DispatchOutput = feval( fcn, args{:});
					else
						fcn( args)
					end
					
				case FunctionDispatchType.AsyncDeffered
					% ASYNC-DEFFERED - Fcn must set output to UserData
					t = timer;
					set(t,...
						'ExecutionMode', 'singleShot',...
						'BusyMode', 'queue',...
						'StartDelay', .001,...
						'Period', .001,...
						'TimerFcn', @(~,~) fcn(args{:}),... % todo
						'StopFcn', @(~,~) timerStopFcn(),...
						'TasksToExecute', 1); 
					start(t);
					
				case FunctionDispatchType.AsyncParallel
					% ASYNC-PARALLEL 
					futureObj = parfeval( fcn, numOut, args{:});
					t = timer;
					set(t,...
						'StartDelay', .001,...
						'Period', .002,...
						'TimerFcn', @(~,~) futureCheckFcn(),... % todo
						'ExecutionMode', 'fixedSpacing',...
						'BusyMode', 'drop',...
						'TasksToExecute', 1000); 					
					obj.DispatchFutureObj = futureObj;
					start(t);
			end
			
			
			% DISPATCH SUB-FUNCTIONS
			function timerStopFcn()
				if numOut > 0
					obj.DispatchOutput = t.UserData;
				end
				delete(t)
			end
			function futureCheckFcn()
				futureState = futureObj.State;
				if ~strcmp( futureState, 'running')
					switch futureState
						case 'finished'
							if numOut > 0
								argsOut = cell(1,numOut);
								[argsOut{:}] = fetchOutputs(futureObj);
								obj.DispatchOutput = argsOut;															
							end
							delete(futureObj);
						case 'error'
							% todo
							handleError(obj, futureObj);
					end
					
					stop(t)
					delete(t)
				end				
			end
			
		end
		function preInitialize(obj) %streamIn
			% Called by subclasses during setupImpl() Performs common/shared initialization tasks.
			% (currently the only task is calling connect(obj.GlobalContextObj))
			
			% CHECK IF OBJECT IS CONFIGURED
			if ~obj.IsConfigured
				configure(obj)
			end
			
			% SET STATE -> INITIALIZING
			obj.State = ignition.core.TaskState.Initializing;
			
			% UPDATE CONFIGURATION STRUCTURE WITH UPDATES TO REFLECTED PROPERTIES
			obj.Configuration = updateFieldsFromProps(obj, obj.Configuration);
			
			% TRIGGER GPU DEVICE SELECTION & PARALLEL POOL CREATION
			% 			if obj.UseGpu || obj.UseParallel
			connect(obj.GlobalContextObj)
			% 			end
			
		end
		function postInitialize(obj)
			
			% INITIALIZE COMMON FRAME-COUNTER IN TASK-DATA
			obj.Cache.NumFramesInputCount = 0;
			obj.Cache.NumFramesOutputCount = 0;
			
			% UPDATE PROPERTIES FROM CONFIGURATION & CACHE STRUCTURES
			fillPropsFromStruct(obj, obj.Configuration);
			fillPropsFromStruct(obj, obj.Cache);
			
			% SET INITIALIZED STATE FLAG
			obj.IsInitialized = true;			
			
			% FIRE EVENT -> READY
			obj.State = ignition.core.TaskState.Ready;
			notify(obj, 'Ready')
			
		end
		function streamIn = preExecute(obj, streamIn)
			
			% UPDATE STATE
			obj.State = ignition.core.TaskState.Queued;				
			obj.BenchTick = tic;
			
			% GET NUMBER OF FRAMES IN INPUT
			numFrames = ignition.shared.getNumFrames(streamIn);
			
			% UPDATE FRAME INPUT COUNTER (PREINCREMENTED)
			obj.Cache.NumFramesInputCount = obj.Cache.NumFramesInputCount + numFrames;			
			
		end
		function streamOut = postExecute(obj, streamOut)
			
			% GET NUMBER OF FRAMES IN OUTPUT
			numFrames = ignition.shared.getNumFrames(streamOut);
			
			% UPDATE FRAME OUTPUT COUNTER (POSTINCREMENTED)
			obj.Cache.NumFramesOutputCount = obj.Cache.NumFramesOutputCount + numFrames;
									
			% ADD BENCHMARK
			addBenchmark(obj.PerformanceMonitorObj, toc(obj.BenchTick), numFrames);						
			
			% FIRE EVENT -> OUTPUTDATAAVAILABLE & READY
			notify(obj, 'OutputDataAvailable');%TODO: add event.eventData
			obj.State = ignition.core.TaskState.Ready;
			notify(obj, 'Ready')
			
		end				
	end
	
	methods (Hidden)
		function setTaskOutput(obj, taskOutput)
			obj.OutputArguments = taskOutput;
		end
	end
	methods (Access = protected)
		function propGroups = getPropertyGroups(obj)
			
			propGroupLabelMap = containers.Map;
			
			% GET METACLASS OF CALLING OBJECT
			mobj = metaclass(obj);
			metaObjectHeirarchy = mobj;
			
			% GET TOP PACKAGE
			pkg = mobj.ContainingPackage;
			while ~isempty(pkg.ContainingPackage)
				pkg = pkg.ContainingPackage;
			end
			parentPackageName = pkg.Name;
			
			% GET SUPERCLASSES OF CALLING OBJECT
			superNames = superclasses(obj);
			for kSuper=1:numel(superNames)
				msuper = meta.class.fromName(superNames{kSuper});
				if ~isempty(msuper.ContainingPackage)
					pkgMatch =  strncmpi( parentPackageName,...
						msuper.ContainingPackage.Name, numel(parentPackageName));
					if pkgMatch
						metaObjectHeirarchy = [metaObjectHeirarchy ; msuper];
					end
				end
			end
			
			% CATEGORIZE PROPERTIES FROM EACH INHERITED CLASS 
			for kObj=1:numel(metaObjectHeirarchy)
				
				% EXTRACT LABELS FROM COMMENT ABOVE PROPERTY BLOCKS IN CLASS-CODE
				propBlocks = ignition.util.getLabeledPropertyBlocks(...
					metaObjectHeirarchy(kObj).Name);
				
				for kBlock=1:numel(propBlocks)
					blockLabel = propBlocks(kBlock).Label;
					
					% ADD TO CURRENT LABELS IF NECESSARY
					if ~isKey(propGroupLabelMap, blockLabel)
						propGroupLabelMap(blockLabel) = propBlocks(kBlock).Properties;
					else
						currentProps = propGroupLabelMap(blockLabel);
						newProps = propBlocks(kBlock).Properties;
						propGroupLabelMap(blockLabel) = [currentProps newProps];
					end
				end
				
			end

			% CONSTRUCT PROPERTY GROUPS
			groupKeys = keys(propGroupLabelMap);
			for kGroup = 1:numel(groupKeys)
				groupLabel = groupKeys{kGroup};
				groupPropList = propGroupLabelMap(groupLabel);
			propGroups(kGroup) = matlab.mixin.util.PropertyGroup(...
				groupPropList, groupLabel);				
			end
			% 				{'Name','Priority','Enabled','DispatchMethod'}, ;
			
			
		end
		function me = handleError(obj, me)
			% 		function logTaskError(~,src,evnt)
			% todo
			
			% todo: handleError(obj, futureObj)
			
			% 			fprintf('An error occurred : src,evnt sent to base workspace\n')
			% 			assignin('base','src',src);
			% 			assignin('base','evnt',evnt);
			notify(obj, 'Error')
			rethrow(me); %TODO
		end
	end
	
	

	
	
	
	
	% OTHER (TO INCLUDE??)
	properties (Hidden)	
		QueuedFcn
		RunningFcn
		TunableConfig
		DynamicConfig
		LockedConfig
		
		PersistentExecutionDependency		
		StoredTaskData
		PersistentData
		SynchronousTaskInput
	end
	
	
	
end
















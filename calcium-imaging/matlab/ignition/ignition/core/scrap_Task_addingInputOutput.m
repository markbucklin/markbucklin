classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		Task ...
		< ignition.core.Operation ...
		& ignition.core.UniquelyIdentifiable
	%Task Reference to properties of current computational environment
	%   TODO:Details
	
	
	
	% CONFIGURATION
	properties		
	end
	%Configuration @ignition.core.TaskConfiguration
	
	% STATE
	properties
		State @ignition.core.TaskState
	end
	
	% STACK
	properties (SetAccess = protected)		
		Stack
	end
	%Stack @ignition.core.TaskStack
				% (or) Data @ignition.core.TaskData
				% (maybe) Data & Stack, where Stack stores the following:
				% -> Stack.config
				% -> Stack.state
				% -> Stack.data
				% -> Stack.taskid
				% -> Stack.performance
				% -----> (perhaps) should all be defined in (derived) TaskExecutor
				
	
	% TASK I/O
	properties (SetAccess = protected)
		%InputArguments @cell
		%OutputArguments @cell
	end
	
	% TASK DEPENDENCIES
	properties (SetAccess = protected)
		InputDependencyObj @ignition.core.Dependency
		PropDependencyObj @containers.Map % todo -> get rid?? or construct listeners
		OutputDependencyObj @ignition.core.Dependency
	end
	
	properties (SetAccess = protected)
		%OutputRequestedFlag @logical % unneccessary?
		%OutputAvailableFlag @logical
	end
	
	
	
	
	
	
	

	
		
	
	methods
		% CONSTRUCTOR
		function obj = Task(fcn, varargin)
			% ignition.core.Task - An Operation with specified I/O Dependencies
			% Usage:
			%			>> obj = ignition.core.Task( operationHandle );
			%
			
			% CALL SUPERCLASS CONSTRUCTOR
			obj = obj@ignition.core.Operation(fcn);
			
			% PARSE ADDITIONAL INPUTS
			if (nargin > 1)
				parseConstructorInput(obj, varargin{:});
			end
		end
		
		% ADD CONFIGURATION TASK
		% configTaskObj = addConfigurationTask(obj, configFcn)
		% configTaskObj = configureUsing(obj, configFcn)
		
		% ADD INITIALIZATION TASK
		% initTaskObj = addInitializationTask(obj, initFcn)
		% initTaskObj = initializeUsing(obj, initFcn)
		
		% ADD STATE UPDATE TASK -> { 'pre', 'post', 'concurrent'?}
				
		% ADD FEEDBACK DEPENDENCY
		
		% SPECIFY REQUIRED (UPSTREAM) DEPENDENCIES
		function bindSource(obj, srcTaskObj, whatIsRequired, inputDest)
			
			
			% DEFAULT REQUIREMENT SOURCE IS FIRST OUTPUT ARGUMENT (IDX=1)
			if (nargin < 3) || isempty(whatIsRequired)
				whatIsRequired = 1;
			end
			
			if nargin < 4
				inputDest = numel(obj.InputDependencyObj) + (1:numel(whatIsRequired));
			end
			
			% CALL MORE SPECIFIC METHOD BASED ON WHAT OUTPUT IS REQUIRED
			if isnumeric(whatIsRequired)
				bindSourceFromOutput(obj, srcTaskObj, whatIsRequired, inputDest)				
				
			else
				bindSourceFromProp(obj, srcTaskObj, whatIsRequired, inputDest)
			end
			
		end
		function bindSourceFromOutput(obj, srcTaskObj, outputIdx, inputDest)
			% dependentTask - task object consuming input from requiredTask
			% requiredTask - task producing output for dependentTask
			% outputIdx - the output argument idx(s) of the function run by requiredTask
			% inputIdx - the input argument idx(s) of the function run by requiredTask
			
			% IF INPUT/OUTPUT ARGUMENT INDICES NOT SPECIFIED -> DEFAULT TO 1
			if nargin < 4
				if nargin < 3
					outputIdx = 1;
				end
				inputDest = 1:numel(outputIdx);
			end
			
			% UPDATE NUM-OUTPUT-ARGS FOR REQUIRED-TASK-OBJECT			
			srcTaskObj.NumOutputArguments = max(...
				srcTaskObj.NumOutputArguments, max(outputIdx(:)));
			
			% UPDATE NUM-INPUT-ARGS FOR DEPENDENT-TASK-OBJECT
			%obj.NumInputArguments = max( obj.NumInputArguments, max(inputIdx(:)));
			% UPDATE NUM-INPUT-ARGS FOR DEPENDENT-TASK-OBJECT IF NUMERIC INPUT-DESTINATION
			if isnumeric(inputDest)
				obj.NumInputArguments = max( obj.NumInputArguments, max(inputDest(:)));
			end
			
			% CONSTRUCT DEPENDENCY OBJECT
			%dependencyObj = ignition.core.InputDependency(...
			%	obj, inputIdx, srcTaskObj, outputIdx);			
			dependencyObj = ignition.core.Dependency.buildDependency(...
				obj, inputDest, srcTaskObj, outputIdx);
			
			% ADD HANDLES TO DEPENDENT & REQUIRED TASK-OBJECTS
			addDependency(obj, dependencyObj, inputDest);
			registerOutputDependency(srcTaskObj, dependencyObj);
			
		end
		function bindSourceFromProp(obj, srcTaskObj, srcProp, inputDest)
		%function bindDependentPropertySource(obj, srcTaskObj, srcProp, inputDest)% 
			% rename StateVar?
			% obj = dependentTaskObj
			
			% IF INPUT/OUTPUT ARGUMENT INDICES NOT SPECIFIED -> DEFAULT TO SAME STATE
			if nargin < 3
				srcProp = {'Stack'};
			end
			if nargin < 4
				inputDest = srcProp;
				% todo -> check isprop(inputDest)
			end
			
			% UPDATE NUM-INPUT-ARGS FOR DEPENDENT-TASK-OBJECT IF NUMERIC INPUT-DESTINATION
			if isnumeric(inputDest)
				obj.NumInputArguments = max( obj.NumInputArguments, max(inputDest(:)));
			end
			
			% CONSTRUCT DEPENDENCY OBJECT
			dependencyObj = ignition.core.Dependency.buildDependency(...
				obj, inputDest, srcTaskObj, srcProp);
			
			% ADD HANDLES TO DEPENDENT & REQUIRED TASK-OBJECTS
			addDependency(obj, dependencyObj, inputDest);
			registerOutputDependency(srcTaskObj, dependencyObj);
			
		end
		function bindSourceFromLatestOutput(obj, srcTaskObjList, outputIdx, inputIdx)
			% IF INPUT/OUTPUT ARGUMENT INDICES NOT SPECIFIED -> DEFAULT TO 1
			numReqTasks = numel(srcTaskObjList);
			if (nargin < 3) || isempty(outputIdx)
				outputIdx = num2cell(ones(1,numReqTasks));
			end
			if nargin < 4				
				inputIdx = 1:(max(1,numel(outputIdx)/numReqTasks));
			end
			assert( iscell(outputIdx) && (numel(outputIdx)==numReqTasks) )
			
			% UPDATE NUM-INPUT-ARGS FOR DEPENDENT-TASK-OBJECT
			obj.NumInputArguments = max( obj.NumInputArguments, max(inputIdx(:)));
			
			% UPDATE NUM-OUTPUT-ARGS FOR REQUIRED-TASK-OBJECT			
			newNumOut = cellfun( @max, {srcTaskObjList.NumOutputArguments}, ...
				cellfun(@max, outputIdx, 'UniformOutput', false), 'UniformOutput', false);
			[srcTaskObjList.NumOutputArguments] = newNumOut{:};
			
			% CONSTRUCT DEPENDENCY OBJECT
			dependencyObj = ignition.core.InputDependency(...
				obj, inputIdx, srcTaskObjList, outputIdx);
			
			% ADD HANDLES TO DEPENDENT & REQUIRED TASK-OBJECTS
			addInputDependency(obj, dependencyObj, inputIdx);
			
			for kSrc = 1:numReqTasks
				reqTask = srcTaskObjList(kSrc);
				registerOutputDependency(reqTask, dependencyObj);
			end
			
		end		
		
		% SPECIFY DEPENDENT (DOWNSTREAM) TASKS
		function bindTarget(obj, targetTaskObj, targetDest, outputIdx)
			
		end
		function bindTargetToProp(obj, targetTaskObj, targetDest, propName)
			
		end
		% --> .NET Observable --> subscribe()		----> "PUSH"-Based Design
		
		% BIND INPUT BY ADDING DEPENDENCY OBJECT TO DOWNSTREAM (DEPENDENT) TASK
		function addDependency(obj, dependencyObj, inputDest)
			
			if isnumeric(inputDest)
				addInputDependency(obj, dependencyObj, inputDest);
			else
				addPropDependency(obj, dependencyObj, inputDest);
			end
			
		end
		function addPropDependency(obj, dependencyObj, propName)
			
			if ~iscellstr(propName)
				propName = {propName};
			end
			for kProp = 1:numel(propName)
				propName = propName{kProp};
				obj.PropDependencyObj(propName) = dependencyObj;
			end
			
		end
		function addInputDependency(obj, dependencyObj, inputIdx)
			
			if (nargin < 3)
				inputIdx = [dependencyObj.DependentInputIdx];
			end
			if isempty(inputIdx)
				inputIdx = 1:numel(dependencyObj);
			end
			
			if (numel(obj.InputDependencyObj) >= max(inputIdx)) ...
					&& ~isempty(obj.InputDependencyObj(inputIdx))
				% todo: replace current dependency or allow for variable source
			else
				obj.InputDependencyObj(inputIdx) = dependencyObj; % todo: deal()??
			end
			
		end
		
		% BIND OUTPUT BY ADDING DEPENDENCY OBJECT TO UPSTREAM (REQUIRED) TASK
		function registerOutputDependency(obj, dependencyObj)
			% Add dependency that indicates downstream tasks (output)
			
			% RECURSIVE CALL FOR MULTIPLE-TASK ASSIGNMENT
			if numel(obj)>1
				for k=1:numel(obj)
					registerOutputDependency(obj(k), dependencyObj)
				end
				return
			end
			
			% CONCATENATE WITH CURRENT DEPENDENCY-OBJECTS (OR EMPTY ARRAY)
			dependencyObj = [obj.OutputDependencyObj, dependencyObj];
			
			% REMOVE ANY EMPTY/INVALID OUTPUT DEPENDENCIES
			dependencyObj = dependencyObj(...
				~isempty(dependencyObj));
			dependencyObj = dependencyObj(isvalid(...
				dependencyObj));					
			
			% STORE HANDLE OF CONCATENATED LIST
			obj.OutputDependencyObj = dependencyObj;
			
		end
		
		
		function [execFcn, taskGraph] = getExecutionChain(obj, mode)
			
			if nargin < 2
				mode = 'upstream';
			end
			
			if strcmpi(mode(1:2), 'up')
				
			else
				
			end
			
			%for kTask=1:numel(obj)
			while true
				depTask = obj;
				depFcn = depTask.Function;
				depArgsIn = cell(1,depTask.NumInputArguments);
				
				allInputDep = depTask.InputDependencyObj;
				for kReq = 1:numel(allInputDep)
					dep = allInputDep(kReq);
					reqObj = dep.RequiredTaskObj;
					depIdx = dep.DependentInputIdx;
					reqIdx = dep.RequiredOutputIdx;
					
					%get fcn ->
					%		argsOut = cell(1,reqObj.NumOutputArgument);
					%		[argsOut{:}] = feval( reqObj, reqObj.NumOutputArguments, argsIn{:});
					% argsIn = next argsOut( next argsoutidx)
					
				end
				
			end
			
			
		end
		
		
		
		
		
		
		%
		% 		% CONTROL
		% 		function setTaskOutput(obj, taskOutput)
		% 			obj.OutputArguments = taskOutput;
		% 		end
		% 		function lock(obj)
		% 		end
		% 		function release(obj)
		% 		end
		% 		function start(obj)
		% 		end
		% 		function execute(obj)
		% 		end
		% 		function run(obj)
		% 		end
		% 		function wait(obj, timeOut)
		% 		end
		% 		function waitAll(obj, timeOut)
		% 		end
		% 		function waitAny(obj, timeOut)
		% 		end
		% 		function continueWith(obj, nextTaskObj)
		% 		end
		%
		%
		% 		% GET FUTURE/PROMISE/OUTPUT
		% 		function [out , ok] = getResult(obj)
		% 		end
		% 		function futureObj = getFuture(obj)
		% 		end
		% 		function addToScheduler(obj, schedObj)
		% 		end
		% 		function updateCache(obj)%maybe
		% 		end
		%
		%
		% 		% GET PROPS (PROP-TYPE)
		% 		function prop = getDynamicProps(obj)
		% 		end
		% 		function prop = getTunableProps(obj)
		% 		end
		% 		function prop = getConfigurationInputProps(obj)
		% 		end
		% 		function config = getConfigurationStruct(obj)
		% 		end
		% 		function cache = getCacheStruct(obj)
		% 		end
		%
		
	end
	methods (Hidden)
		
	end
	methods (Static, Hidden)
		
	end
	
% 	function initializeTaskIO( obj )
% 	
% 	op = obj.FunctionHandle;
% 	if isempty(op)
% 		return
% 	end
% 	
% 	% todo
% 	obj.NumInputArguments = op.NumInputs;
% 	obj.InputArguments = cell(1,op.NumInputs);
% 	obj.NumOutputArguments = op.NumOutputs;
% 	obj.OutputArguments = cell(1,op.NumOutputs);
% 	
% 	end
	
	% addInitialRequirement
	% addInitialDependency
	% addDirectOutput
	% addSynchronousOutput
	% addStreamOutput
	% addTunableOutput
	% addCacheOutput
	% addConfigurationPropOutput
	% requireConfigurationInput
	% requireStaticInput
	% requireTunableInput
	% requireRecurrentCacheInput
	% requireInitialInput
	% requireProp
	% requireDirectInput
	% requireStreamInput
	% requireBufferedInput
	
	% requirePropDependency
	% requireStreamDependency
	% requireCacheDependency
	% requireDirectDependency
	% requireInitDependency
	
	% createDirectStream
	% createBufferedStream
	% createTunableStream
	% createCacheUpdateStream
	% createEventStream
	% createAsyncStream
	% createSynchronousStream
	% createSplitStream
	% createParallelStream
	% createDelayedStream
	% createPropertyStream
	% createOutputStream
	% createInputStream
	% createScalarStream
	% createStaticStream
	% createFrameStream
	% createLowLatencyStream
	% createOffsetSuppressedStream
	
	
	
	
	
	
	properties (Hidden)
		InputArgumentNames @cell
		OutputArgumentNames @cell
	end
	
	
	
	
	
end


%
% function mapDependency(obj, inputIdx, upstreamTask, outputIdx, type)
%
% if (nargin<5)
% 	type = 'synchronous';
% end
%
% dep = registerOutputDependency( upstreamTask, outputIdx);
%
% switch lower(type(1:4))
% 	case 'sync' % SYNCHRONOUS
% 		supplyDependency(obj, dep, inputIdx);
%
% 	case 'init' % INITIAL-VALUE
% 		supplyInitialDependency(obj, dep, inputIdx);
%
% 	case 'stat' % STATIC-VALUE
% 		supplyStaticDependency(obj, dep, inputIdx);
%
% 	otherwise
% 		% todo -> warning
%
% end
%
% end
% % REGISTER DEPENDENCY (CLOSURE PROMISE -> TASK OUTPUT)
% function regDep = registerDependency(obj, depKey)
%
% % INITIALIZE OUTPUT
% regDep = ignition.core.Dependency.empty;
%
% if isnumeric(depKey)
% 	% NUMERIC (OUTPUT-ARGUMENT IDX)
% 	regDep = registerOutputDependency(obj, depKey);
%
% elseif ischar(depKey)
% 	% CHARACTER (TASK PROPERTY)
% 	regDep = registerPropDependency(obj, depKey);
%
% elseif iscell(depKey)
% 	% ALLOW MULTI AND/OR COMBINATION
% 	isIdxKey = cellfun(@isnumeric, depKey);
% 	isPropKey = cellfun(@ischar, depKey);
% 	if any(isIdxKey)
% 		regDep(isIdxKey) = registerOutputDependency(obj, depKey(isIdxKey));
% 	end
% 	if any(isPropKey)
% 		regDep(isPropKey) = registerPropDependency(obj, depKey(isPropKey));
% 	end
%
% end
%
% end
% function outputDep = registerOutputDependency(obj, outputIdx)
% % Serve as task futures
%
% % INITIALIZE OUTPUT
% outputDep = ignition.core.Dependency.empty;
% assert(obj.NumOutputArguments>=1); %todo
%
% % ALLOW UNSPECIFIED OUTPUT-IDX ARGUMENT TO DEFAULT TO ALL
% if (nargin < 2)
% 	outputIdx = [];
% end
% if isempty(outputIdx)
% 	outputIdx = 1:obj.NumOutputArguments;
% end
%
% % ALLOW CELL INPUT
% if iscell(outputIdx)
% 	outputIdx = [outputIdx{:}];
% end
%
% % ALLOW MULTI-OUTPUT IDX SPECIFICIATION
% for k=1:numel(outputIdx)
% 	idx = outputIdx(k);
% 	assert(isnumeric(idx)); % todo
%
% 	% CREATE NEW DEPENDENCY HANDLE
% 	dep = ignition.core.Dependency( obj, idx);
%
% 	% ADD TO ARRAY OF REGISTERED OUTPUT DEPENDENCIES
% 	obj.OutputDependencyObj = [obj.OutputDependencyObj, dep];
%
% 	% RETURN ARRAY OF DEPENDENCY OBJECTS
% 	outputDep(k) = dep;
%
% end
%
% end
% function propDep = registerPropDependency(obj, propName)
%
% % INITIALIZE OUTPUT
% propDep = ignition.core.Dependency.empty;
%
% % ALLOW CELL-STRING (MULTIPLE PROPERTY) INPUT
% if ischar(propName)
% 	propName = {propName};
% end
% for k=1:numel(propName)
% 	prop = propName{k};
% 	assert(isprop(obj, prop));
%
% 	% CREATE NEW DEPENDENCY HANDLE
% 	dep = ignition.core.Dependency( obj, prop);
%
% 	% ADD TO CONTAINERS.MAP STORAGE OF SUPPLIED PROPERTIES
% 	if ~isvalid(obj.PropDependencyObj)
% 		obj.PropDependencyObj = containers.Map;
% 	end
% 	if isKey(obj.PropDependencyObj, prop)
% 		% ADD TO OTHER REQUESTS FOR SAME PROPERTY
% 		currentDep = obj.PropDependencyObj(prop);
% 		obj.PropDependencyObj(prop) = [currentDep, dep];
%
% 	else
% 		% INITIALIZE VALUE AT 'PROPNAME' KEY WITH 1ST DEPENDENCY HANDLE
% 		obj.PropDependencyObj(prop) = dep;
% 	end
%
% 	% RETURN ARRAY OF DEPENDENCY OBJECTS
% 	propDep(k) = dep;
%
% end
%
%
% end


% InitialInputDependency @ignition.core.Dependency

% properties (SetAccess = protected, Hidden)
% 		Parent
% 		State
% 		StateEnum
% 		Error
% 		ErrorMessage
% 		ErrorID
% 		Warnings
% 		Worker
% 	end
% properties (Hidden)
% 		RunningFcn %todo
% 		FinishedFcn %todo
% 	end








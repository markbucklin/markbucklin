classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		Task < ignition.core.Object & handle & matlab.mixin.CustomDisplay
	%Task Reference to properties of current computational environment
	%   TODO:Details
	
	
	
	
	% TASK CONTROL
	properties				
		Priority = 0
		Enabled @logical scalar = false % todo
		DispatchMethod @ignition.core.FunctionDispatchType
	end
	
	% TASK FUNCTION
	properties (SetAccess = protected)
		Name = ''
		OperationHandle @ignition.core.Operation
		InitialInputDependency @ignition.core.Dependency
		InputDependency @ignition.core.Dependency		
		PropDependency @containers.Map
		OutputRequestedFlag @logical
		OutputAvailableFlag @logical
	end
	
	% INPUT/OUTPUT DESCRIPTION
	properties (SetAccess = protected)					
		InputArguments @cell
		OutputArguments @cell % remove -> put in future object instead
		NumInputArguments = 0
		NumOutputArguments = 0
		IsStaticInput @logical
		IsInitializedInput @logical
	end
	
	% add ID property in persistent variable in constructor or static method that registers all ids
	
	
	
	
	% ##################################################
	% USER CALLABLE METHODS
	% ##################################################	
	methods
		% CONSTRUCTOR
		function obj = Task(op, varargin)
			% obj = ignition.core.Task( operationHandle );
			
			% ASSIGN OPERATION HANDLE
			if (nargin > 0)
				obj.OperationHandle = op;
				obj.OutputRequestedFlag(op.NumOutputs) = false;
				
				
				% todo
				obj.NumInputArguments = op.NumInputs;
				obj.InputArguments = cell(1,op.NumInputs);
				obj.NumOutputArguments = op.NumOutputs;
				obj.OutputArguments = cell(1,op.NumOutputs);
				obj.IsStaticInput = false(1,op.NumInputs);
				obj.IsInitializedInput = false(1,op.NumInputs);
				
				if (nargin > 1)
					dep = varargin{1};
					supplyDependency(obj, dep)
				end
				
			end
			
		end
		
		% CONTROL
		function lock(obj)
		end
		function release(obj)
		end
		function start(obj)
		end
		function wait(obj, timeOut)
		end
		function waitAll(obj, timeOut)
		end
		function waitAny(obj, timeOut)
		end
		function continueWith(obj, nextTaskObj)
		end
		
		
		% GET FUTURE/PROMISE?
		function futureObj = getFuture(obj)
		end
		function addToScheduler(obj, schedObj)			
		end
		
		
		% GET PROPS (PROP-TYPE)
		function prop = getDynamicProps(obj)
		end
		function prop = getTunableProps(obj)
		end
		function prop = getConfigurationInputProps(obj)
		end
		function config = getConfigurationStruct(obj)
		end
		function cache = getCacheStruct(obj)
		end
		
		
		% SUPPLY DEPENDENCY (CLOSURE FUTURE -> TASK INPUT)
		function supplyStaticDependency(obj, dependencyObj, inputIdx)
			
			supplyDependency(obj, dependencyObj, inputIdx);
			obj.IsStaticInput(inputIdx) = true;
			
			
		end
		function supplyInitialDependency(obj, dependencyObj, inputIdx)
			
			if nargin < 3
				inputIdx = 1:numel(dependencyObj);
			end
			
			for k=1:numel(inputIdx)
				idx = inputIdx(k);
				dep = dependencyObj(k);
				obj.InitialInputDependency(idx) = assignConsumer(dep, obj, idx);
				obj.IsInitializedInput(idx) = true;
			end
			
			
		end
		function supplyDependency(obj, dependencyObj, inputIdx)
			% producerTaskHandle, producerTaskAccessor
			
			if nargin < 3
				inputIdx = 1:numel(dependencyObj);
			end
			
			for k=1:numel(inputIdx)
				idx = inputIdx(k);
				dep = dependencyObj(k);
				obj.InputDependency(idx) = assignConsumer(dep, obj, idx);
			end
			
		end
		
		% MAP DEPENDENCY
		function mapDependency(obj, inputIdx, upstreamTask, outputIdx, type)
			
			if (nargin<5)
				type = 'synchronous';
			end
			
			dep = registerOutputDependency( upstreamTask, outputIdx);
			
			switch lower(type(1:4))
				case 'sync' % SYNCHRONOUS					
					supplyDependency(obj, dep, inputIdx);
					
				case 'init' % INITIAL-VALUE
					supplyInitialDependency(obj, dep, inputIdx);
					
				case 'stat' % STATIC-VALUE
					supplyStaticDependency(obj, dep, inputIdx);
					
				otherwise
					% todo -> warning
					
			end
			
		end
		
		% REGISTER DEPENDENCY (CLOSURE PROMISE -> TASK OUTPUT)
		function outputDep = registerOutputDependency(obj, outputIdx)
			% Serve as task futures
			
			% INITIALIZE OUTPUT
			outputDep = ignition.core.Dependency.empty;
			assert(obj.NumOutputArguments>=1); %todo
			
			% ALLOW UNSPECIFIED OUTPUT-IDX ARGUMENT TO DEFAULT TO ALL
			if (nargin < 2)
				outputIdx = [];
			end
			if isempty(outputIdx)
				outputIdx = 1:obj.NumOutputArguments;
			end
			
			% ALLOW CELL INPUT
			if iscell(outputIdx)
				outputIdx = [outputIdx{:}];
			end
			
			% ALLOW MULTI-OUTPUT IDX SPECIFICIATION
			for k=1:numel(outputIdx)
				idx = outputIdx(k);
				assert(isnumeric(idx)); % todo
								
				% CREATE NEW DEPENDENCY HANDLE
				dep = ignition.core.Dependency( obj, idx);
				
				% ADD TO ARRAY OF REGISTERED OUTPUT DEPENDENCIES
				obj.OutputDependency = [obj.OutputDependency, dep];
												
				% RETURN ARRAY OF DEPENDENCY OBJECTS
				outputDep(k) = dep;
				
			end
			
		end
		function propDep = registerPropDependency(obj, propName)
			
			% INITIALIZE OUTPUT
			propDep = ignition.core.Dependency.empty;
			
			% ALLOW CELL-STRING (MULTIPLE PROPERTY) INPUT
			if ischar(propName)
				propName = {propName};
			end			
			for k=1:numel(propName)
				prop = propName{k};
				assert(isprop(obj, prop));
				
				% CREATE NEW DEPENDENCY HANDLE
				dep = ignition.core.Dependency( obj, prop);
				
				% ADD TO CONTAINERS.MAP STORAGE OF SUPPLIED PROPERTIES
				if ~isvalid(obj.PropDependency)
					obj.PropDependency = containers.Map;
				end
				if isKey(obj.PropDependency, prop)
					% ADD TO OTHER REQUESTS FOR SAME PROPERTY
					currentDep = obj.PropDependency(prop);
					obj.PropDependency(prop) = [currentDep, dep];
					
				else
					% INITIALIZE VALUE AT 'PROPNAME' KEY WITH 1ST DEPENDENCY HANDLE
					obj.PropDependency(prop) = dep;
				end
				
				% RETURN ARRAY OF DEPENDENCY OBJECTS
				propDep(k) = dep;
				
			end
				
			
		end
		function regDep = registerDependency(obj, depKey)
			
			% INITIALIZE OUTPUT
			regDep = ignition.core.Dependency.empty;
			
			if isnumeric(depKey)
				% NUMERIC (OUTPUT-ARGUMENT IDX)
				regDep = registerOutputDependency(obj, depKey);
				
			elseif ischar(depKey)
				% CHARACTER (TASK PROPERTY)
				regDep = registerPropDependency(obj, depKey);				
				
			elseif iscell(depKey)
				% ALLOW MULTI AND/OR COMBINATION
				isIdxKey = cellfun(@isnumeric, depKey);
				isPropKey = cellfun(@ischar, depKey);
				if any(isIdxKey)
					regDep(isIdxKey) = registerOutputDependency(obj, depKey(isIdxKey));
				end				
				if any(isPropKey)
					regDep(isPropKey) = registerPropDependency(obj, depKey(isPropKey));
				end
				
			end
						
		end

	end
	
	
	
	
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
	
	

	







properties (Hidden)
		InputArgumentNames @cell
		OutputArgumentNames @cell
end








	
end















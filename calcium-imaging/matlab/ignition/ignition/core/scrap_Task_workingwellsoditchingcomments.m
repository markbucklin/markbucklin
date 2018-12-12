classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		Task ...
		< ignition.core.Operation ...
		& ignition.core.UniquelyIdentifiable
	%Task Reference to properties of current computational environment
	%   TODO:Details
	
	
	
	% CONFIGURATION
	properties
	end
	
	% CONTROL
	properties
	end
	
	% STATE
	properties
	end
	
	% DATA
	properties
	end
	
	% TASK I/O
	properties (SetAccess = protected)%immutable)
		Input @ignition.core.TaskInput
		Output @ignition.core.TaskOutput
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
			
			% CONSTRUCT TASK INPUT/OUTPUT OBJECTS
			initializeTaskInput(obj)
			initializeTaskOutput(obj)
			
		end
		function initializeTaskInput(obj)
			k = numel(obj.Input);
			while k<obj.NumInputArguments
				k=k+1;
				obj.Input(k) = ignition.core.TaskInput(obj,k);
			end
		end
		function initializeTaskOutput(obj)
			k = numel(obj.Output);
			while k<obj.NumOutputArguments
				k=k+1;
				obj.Output(k) = ignition.core.TaskOutput(obj,k);
			end
		end
		
		
		% SPECIFY REQUIRED (UPSTREAM) SOURCES TO RECEIVE INPUT FROM
		function receiveInputFrom(obj, srcObj, whatIsRequired, inputIdx)
			
			
			% DEFAULT REQUIREMENT SOURCE IS FIRST OUTPUT ARGUMENT (IDX=1)
			if (nargin < 3) || isempty(whatIsRequired)
				whatIsRequired = 1;
			end
			
			if nargin < 4
				inputIdx = 1:numel(whatIsRequired);
			end
			
			% CALL MORE SPECIFIC METHOD BASED ON WHAT OUTPUT IS REQUIRED
			if isnumeric(whatIsRequired)
				receiveInputFromTaskOutput(obj, srcObj, whatIsRequired, inputIdx)
				
			else
				receiveInputFromProp(obj, srcObj, whatIsRequired, inputIdx)
			end
			
			
			% todo -> make generic for receiving properties from src
			
			
		end
		function receiveInputFromTaskOutput(obj, srcTaskObj, outputIdx, inputIdx)
			% dependentTask - task object consuming input from requiredTask
			% requiredTask - task producing output for dependentTask
			% outputIdx - the output argument idx(s) of the function run by requiredTask
			% inputIdx - the input argument idx(s) of the function run by requiredTask
			
			% IF INPUT/OUTPUT ARGUMENT INDICES NOT SPECIFIED -> DEFAULT TO 1
			if nargin < 4
				if nargin < 3
					outputIdx = 1;
				end
				inputIdx = 1:numel(outputIdx);
			end
			assert( isnumeric(inputIdx) );
			assert( isnumeric(outputIdx) );
			assert( numel(outputIdx) == numel(inputIdx) ); % todo: message
			
			% UPDATE NUM-INPUT-ARGS FOR RECEIVING-TASK-OBJECT
			if obj.NumInputArguments < max(inputIdx(:))
				obj.NumInputArguments = max(inputIdx(:));
				initializeTaskInput(obj);
			end
			
			% UPDATE NUM-OUTPUT-ARGS FOR SENDING-TASK-OBJECT
			if srcTaskObj.NumOutputArguments < max(outputIdx(:))
				srcTaskObj.NumOutputArguments = max(outputIdx(:));
				initializeTaskOutput(srcTaskObj);
			end
			
			% LINK
			for k = 1:numel(outputIdx)
				link( srcTaskObj.Output(outputIdx(k)), obj.Input(inputIdx(k)) );
			end
			
		end
		function receiveInputFromProp(obj, srcObj, srcPropName, inputIdx)
			%function bindDependentPropertySource(obj, srcTaskObj, srcProp, inputDest)%
			% rename StateVar?
			% obj = dependentTaskObj
			
			% IF INPUT/OUTPUT ARGUMENT INDICES NOT SPECIFIED -> DEFAULT TO SAME STATE
			if nargin < 3
				srcPropName = {'Data'}; % todo -> build exposed props
			end
			if nargin < 4
				inputIdx = 1:numel(srcPropName);
			end
			if ischar(srcPropName)
				srcPropName = {srcPropName};
			end
			numProp = numel(srcPropName);
			numIdx = numel(inputIdx);
			assert( iscellstr(srcPropName) );
			assert( isnumeric(inputIdx) );
			assert( (numProp == numIdx) || (numIdx == 1) ); % todo: message
			
			% UPDATE NUM-INPUT-ARGS FOR RECEIVING-TASK-OBJECT
			if obj.NumInputArguments < max(inputIdx(:))
				obj.NumInputArguments = max(inputIdx(:));
				initializeTaskInput(obj);
			end
			
			% LINK
			if (numProp == numIdx)
				for k = 1:numProp
					name = srcPropName{k};
					val = srcObj.(name);
					propSource = ignition.core.TaskProperty( srcObj, name, val);
					idx = inputIdx(k);
					link( obj.Input(idx), propSource);
				end
				
			else
				% todo
				srcData = ignition.core.TaskData( srcObj, srcPropName, getStructFromProps(srcObj,srcPropName));
				link( obj.Input, srcData);
			end
			
			
			
		end
		
		% SPECIFY DEPENDENT (DOWNSTREAM) TASKS
		function sendOutputTo(obj, targetTaskObj, targetDest, outputIdx)
			
		end
		function sendPropTo(obj, targetTaskObj, targetDest, propName)
			
		end
		% --> .NET Observable --> subscribe()		----> "PUSH"-Based Design
		
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
		function src = getInputSource(obj)
			taskIn = [obj.Input];
			src = [taskIn.Source];
		end
		function task = getUpstreamTask(obj)
			src = getInputSource(obj);
			numSrc = cellfun(@numel, src);
			N = max(numSrc);
			for k=1:N
				idx = k;
				task{k} = cellfun(@getIdxOrLastTask, src, 'UniformOutput',false);
			end
			
			function t = getIdxOrLastTask(allSrc)
				nextSrc = allSrc(min(idx,numel(allSrc)));
				t = nextSrc.TaskObj;
			end
		end
		
	end
	
	
	methods (Sealed)
		function taskList = getUpstreamTaskList(obj)
			
			% BEGIN LIST WITH OBJECT
			%[taskID, uIdx, ~] = unique([obj.ID]);
			%taskID = taskID(:)';
			%taskList = obj(uIdx)';
			%chk = numel(taskList);
			
			taskList = obj(:)';
			taskID = [taskList.ID];
			curtask = taskList;
			
			% LOOP WHILE UNTIL NO NEW TASKS ARE FOUND
			while true
				% GET SOURCES (TASK OUTPUT) FOR TASK INPUT
				io = [curtask.Input];
				src = [io.Source];
				
				% GET TASK OBJECT THAT GENERATES UPSTREAM SOURCES
				uptask = [src.TaskObj];
				id = [uptask.ID];
				[id, tskidx, ~] = unique(id);
				
				% CHECK IF THIS ROUND OF UPSTREAM TASKS MATCH TASKS ALREADY FOUND
				idnew = ~any(bsxfun(@eq, id(:), taskID ), 2);
				if ~any(idnew)
					break
				end
				
				% PREPEND NEW IDs AND TASKS TO LIST
				taskID = [ id(idnew) , taskID];
				curtask = uptask(tskidx(idnew));
				taskList = [ curtask(:)' , taskList(:)'];
				
			end
			
			disp(strvcat({taskList.FunctionString})) % todo
			
		end
		function taskList = getDownstreamTaskList(obj)
			
			taskList = obj(:)';
			taskID = [taskList.ID];
			curtask = taskList;
			
			% LOOP WHILE UNTIL NO NEW TASKS ARE FOUND
			while true
				% GET SOURCES (TASK OUTPUT) FOR TASK INPUT
				io = [curtask.Output]; if isempty(io), break, end
				targ = [io.Target]; if isempty(targ), break, end
				
				
				% GET TASK OBJECT THAT GENERATES UPSTREAM SOURCES
				downtask = [targ.TaskObj];
				id = [downtask.ID];
				[id, tskidx, ~] = unique(id);
				
				% CHECK IF THIS ROUND OF UPSTREAM TASKS MATCH TASKS ALREADY FOUND
				idnew = ~any(bsxfun(@eq, id(:), taskID ), 2);
				if ~any(idnew)
					break
				end
				
				% PREPEND NEW IDs AND TASKS TO LIST
				taskID = [ id(idnew) , taskID];
				curtask = downtask(tskidx(idnew));
				taskList = [ curtask(:)' , taskList(:)'];
				
			end
			
			disp(strvcat({taskList.FunctionString})) % todo
			
		end
		
	end
	methods (Access = protected, Sealed)
		function displayNonScalarObject(objAry)
			dimStr = matlab.mixin.CustomDisplay.convertDimensionsToString(objAry);
			cName = matlab.mixin.CustomDisplay.getClassNameForHeader(objAry);
			headerStr = [dimStr,' ',cName,' members:'];
			header = sprintf('%s\n',headerStr);
			disp(header)
			for ix = 1:length(objAry)
				o = objAry(ix);
				if ~isvalid(o)
					str1 = matlab.mixin.CustomDisplay.getDeletedHandleText;
					str2 = matlab.mixin.CustomDisplay.getClassNameForHeader(o);
					headerInv = [str1,' ',str2];
					tmpStr = [num2str(ix),'. ',headerInv];
					numStr = sprintf('%s\n',tmpStr);
					disp(numStr)
				else
					try
						tskName = o.Name;
						funcString = o.FunctionString;
						numOut = o.NumOutputArguments;
						numIn = o.NumInputArguments;
						
						propList = struct(...
							'Name', tskName,...
							'Function', funcString,...
							'NumIn', numIn,...
							'NumOut', numOut);
						propgrp = matlab.mixin.util.PropertyGroup(propList);
						matlab.mixin.CustomDisplay.displayPropertyGroups(o,propgrp);
						%[propGroups,tmp] = getCustPropertyGroups(o)
					catch
						propgrp = getCustomPropertyGroups(o);
						matlab.mixin.CustomDisplay.displayPropertyGroups(o,propgrp);
					end
					fprintf('\n')
				end
			end
		end
		
		
		
		
		
		
		
		
		% todo
		% 		function displayScalarObject(obj)
		% 			% header
		% 			disp(getHeader(obj));
		% 			group = getPropertyGroups(obj);
		% 			detailsStr = evalc('details(obj)');
		% 			nsplits = strsplit(detailsStr, '\n');
		% 			filesStr = nsplits(~cellfun(@isempty, strfind(nsplits, 'Files: ')));
		% 			% Find the indent spaces from details
		% 			nFilesIndent = strfind(filesStr{1}, 'Files: ') - 1;
		% 			if nFilesIndent > 0
		% 				% File Properties
		% 				filesIndent = [sprintf(repmat(' ',1,nFilesIndent)) 'Files: '];
		% 				nlspacing = sprintf(repmat(' ',1,numel(filesIndent)));
		% 				if isempty(obj.Files)
		% 					nlspacing = '';
		% 				end
		% 				%import matlab.io.datastore.internal.cellArrayDisp;
		% 				%filesStrDisp = cellArrayDisp(obj.Files, true, nlspacing);
		% 				%disp([filesIndent filesStrDisp]);
		% 				% Remove Files property from the group, since custom
		% 				% display is used for Files.
		% 				group.PropertyList = rmfield(group.PropertyList, 'Files');
		% 			end
		% 			matlab.mixin.CustomDisplay.displayPropertyGroups(obj, group);
		% 			disp(getFooter(obj));
		% 		end
		
		
		
		
		
		
		
		
		
		
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








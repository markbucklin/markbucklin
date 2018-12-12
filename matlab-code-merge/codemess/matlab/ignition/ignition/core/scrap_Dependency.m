classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		Dependency ...
		< ignition.core.Handle ...
		& ignition.core.UniquelyIdentifiable ...
		& ignition.core.CustomDisplay ...
		& matlab.mixin.Heterogeneous
	
	
	
	% REQUIRED-TASK (PRODUCER) PROPERTIES
	properties
		RequiredTaskObj @ignition.core.Task
		RequiredProp @cell % StateVariableName
		RequiredOutputIdx @cell
	end
	
	% DEPENDENT-TASK (CONSUMER) PROPERTIES
	properties
		DependentTaskObj @ignition.core.Task scalar
	end
	
	properties
		IsFromTaskProp @logical
		IsFromTaskOutput @logical
		IsDefined @logical = false
	end
	properties  (Abstract)
		IsForTaskInput @logical % not sure about this one yet
	end
	
	
	
	methods
		function obj = Dependency(varargin)
			% >> obj = Dependency( upstreamTaskObj, outputIdx);
			% >> obj = Dependency( upstreamTaskObj, 'PropName');
			% >> obj = Dependency( upstreamTaskObj, {'PropName1','PropName2'});
			
			if nargin
				% SPECIFY THE SOURCE BY TASK-OBJECT & PROPERTY-NAME OR OUTPUT-INDEX
				bindToRequiredTask(obj, varargin{:});
				
			end
		end
		function bindToRequiredTask(obj, requiredTaskObj, requiredResource, multiTaskOption)
			
			if nargin < 3
				requiredResource = 1;				
			end
			if nargin < 4
				multiTaskOption = ''; % 'any' or 'all' todo
			end
			
			
			% GET NUMBER OF TASKS PASSED TO SINGLE INPUT DEPENDENCY
			numReqTask = numel(requiredTaskObj);
			
			if isa(requiredTaskObj, 'ignition.core.Task')
				% DYNAMIC DEPENDENCY SUPPLIED BY TASK
				obj.RequiredTaskObj = requiredTaskObj;
				
				% CHECK NEEDS WITH REQUIRED TASK ABILITY (WHERE THE DATA WILL COME FROM)
				key = requiredResource;
				
				% todo -> move iscell(key) up and for-loop around each cell
				
				if ischar(key) || iscellstr(key) %~isnumeric(key)
					% TASK PROPERTY (SPECIFIED NAME)
					if ischar(key)
						key = {key};
					end
					assert( iscellstr(key), 'Ignition:Dependency:InvalidState');
					obj.RequiredProp = key;
					obj.IsFromTaskProp = true;										
					
				else
					% TASK OUTPUT (SPECIFIED IDX)					
					if iscell(key)
						cIdxOut = key;
					elseif isnumeric(key)
						cIdxOut = {key};
					else
						error(message('Ignition:Dependency:UnknownResourceSpecificiation',mfilename)) %todo
					end
										
					if numReqTask>1 && numel(cIdxOut)==1
						cIdxOut = repelem(cIdxOut,1,numReqTask);
					end
					assert( numel(cIdxOut) == numReqTask);
					
					% CHECK THAT INPUT SPEC IS VALID FOR NUMBER OF DEPENDENT TASK INPUTS (todo)
					
					for kSrc = 1:numReqTask
						idx = cIdxOut{kSrc};
						numOutputs = requiredTaskObj(kSrc).NumOutputArguments;
						assert( isnumeric(idx) && all(idx<=numOutputs), 'Ignition:Dependency:InvalidIdx');
						obj.RequiredOutputIdx{kSrc} = idx;						
					end
					
					obj.IsFromTaskOutput = true; % todo -> make as long as requiredTaskObj
					
					
				end
			end
			
			% SET FLAGS SPECIFYING THE TYPE OF OUTPUT REQUIRED
			
			% TASK-PROPERTY (TASK STATE) -> POTENTIALLY ASYNCHRONOUS/EVENT-BASED UPDATES
			obj.IsFromTaskProp = isempty(obj.RequiredOutputIdx);
			
			% TASK OUTPUT -> NECESSARILY SYNCHRONOUS, THOUGH MAYBE JUST SINGLE OUTPUT CALL (I.E. INIT)
			obj.IsFromTaskOutput = ~obj.IsFromTaskProp;
			
			% FLAG THAT SOURCE THAT FILLS DEPENDENCY IS DEFINED
			obj.IsDefined = true;
			
			% todo: add access function handle
			
		end		
	end
	
	
	methods (Static)
		function obj = buildDependency(dependentTaskObj, dependentDestination, varargin)
			
			if isnumeric(dependentDestination)
				% INPUT DEPENDENCY CONSTRUCTOR
				obj = ignition.core.InputDependency(...
					dependentTaskObj, dependentDestination, varargin{:});
				
			else
				% PROPERTY DEPENDENCY CONSTRUCTOR
				obj = ignition.core.PropDependency(...
					dependentTaskObj, dependentDestination, varargin{:});
				
			end
		end
	end
	
	
	
	
	
	
	
	
	
	
end













%%
% function obj = assignDependentTask(obj, consumerTask, varargin)
% 			
% 			obj.DependentTaskObj = [obj.DependentTaskObj, consumerTask];
% 			N = numel(obj.DependentTaskObj);
% 			
% 			if nargin > 2
% 				if ischar(varargin{1})
% 					obj.DependentProp{N} = varargin{1};
% 					obj.IsForInput(N) = false;
% 				elseif iscellstr(varargin)
% 					%todo
% 				else
% 					obj.DependentInputIdx = varargin{1};
% 					obj.IsForInput(N) = true;
% 				end
% 			else
% 				obj.DependentInputIdx = 1;
% 				obj.IsForInput(N) = true;
% 			end
% 			
% 		end
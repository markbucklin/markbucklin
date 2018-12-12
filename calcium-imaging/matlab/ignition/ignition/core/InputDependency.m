classdef InputDependency < ignition.core.Dependency
	
	
	% DEPENDENT-TASK (CONSUMER) PROPERTIES
	properties
		DependentInputIdx @double
	end
		
	properties 
		IsForTaskInput @logical = true	% defined abstract in dependency class
	end
	
	
	methods
		function obj = InputDependency( dependentTaskObj, dependentInputIdx, varargin)
			
			% CALL SUPERCLASS
			obj = obj@ignition.core.Dependency(varargin{:});
			
			% SPECIFY DEPENDENT TASK NEEDS (WHERE THE DATA WILL GO)
			if nargin
				bindToDependentTaskInput(obj, dependentTaskObj, dependentInputIdx)				
			end
			
		end
		function bindToDependentTaskInput(obj, dependentTaskObj, inputIdx)
			
			if isa(dependentTaskObj, 'ignition.core.Task')
					% DYNAMIC DEPENDENCY SUPPLIED BY TASK
					obj.DependentTaskObj = dependentTaskObj;
					
					% CHECK THAT INPUT SPEC IS VALID FOR NUMBER OF DEPENDENT TASK INPUTS (todo)					
					numInputs = dependentTaskObj.NumInputArguments;
					
					% DEFAULT TO ALL
					if nargin < 3
						inputIdx = 1:numInputs;
						%dependentInputIdx = numel(obj.DependentInputIdx) + 1;
					end															
					assert( isnumeric(inputIdx) && all(inputIdx<=numInputs), 'Ignition:InputDependency:InvalidIdx');
					% also will need to check that number of required indices matches number of dependent (todo)
					
					obj.DependentInputIdx = inputIdx;
					
				end
			
		end
	end
	
	
	
	
	
	
	
	
	
	
	
	
	
end
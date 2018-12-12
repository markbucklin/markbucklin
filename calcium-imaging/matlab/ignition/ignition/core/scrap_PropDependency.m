classdef PropDependency < ignition.core.Dependency
	
	
	
	% DEPENDENT-TASK (CONSUMER) PROPERTIES
	properties
		DependentProp @cell
	end
		
	properties 
		IsForTaskInput @logical = false
	end
	
	
	methods
		function obj = PropDependency( dependentTaskObj, dependentProp, varargin)
			
			obj = obj@ignition.core.Dependency(varargin{:});
			
			if nargin				
				bindToDependentTaskProp( obj, dependentTaskObj, dependentProp)
			end
			
			% todo: add access function handle
			
		end
		function bindToDependentTaskProp( obj, dependentTaskObj, dependentProp)
			
			if isa(dependentTaskObj, 'ignition.core.Task')
					% DYNAMIC DEPENDENCY SUPPLIED BY TASK
					obj.DependentTaskObj = dependentTaskObj;
					
					if nargin > 1
						% CHECK THAT DEPENDENT TASK PROPERTY(S) SPECIFIED AS CELL ARRAY
						if ischar(dependentProp)
							dependentProp = {dependentProp};
						end
						assert( iscellstr(dependentProp), 'Ignition:PropDependency:InvalidProp');				
						
					end
				end
			
		end
		
	end
	
	
	
	
	
	
	
	
	
	
	
	
	
end


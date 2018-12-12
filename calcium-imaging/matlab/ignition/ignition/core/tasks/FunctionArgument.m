classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		FunctionArgument ...
		< ignition.core.tasks.TaskIO
	
	
	
	
	properties (SetAccess = protected)
		Idx
	end
	
	
	
	events
		
	end
	
	
	methods
		% CONSTRUCTOR
		function obj = FunctionArgument( task, idx)
			% TaskOutput - Represents output arguments for a Task Object
			obj = obj@ignition.core.tasks.TaskIO(task);			
			obj.Idx = idx;
		end
		
	end
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
end



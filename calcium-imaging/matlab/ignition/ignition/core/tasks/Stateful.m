classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		Stateful < ignition.core.Task
	
	
	
	
	% STATE
	properties
	end
	
	
	properties (SetAccess = protected)
		State @ignition.core.TaskInterface
		StateUpdateTask @ignition.core.Task
	end
	
	
	
	
	
	methods
		function obj = Stateful( fcn )
			import ignition.core.TaskInterface			
			updateTask = ignition.core.Task( fcn );
			obj.StateUpdateTask = updateTask;			
			tag = 'STATE';
			obj.State = TaskInterface.buildFromPropTag( obj, tag, updateTask);
			
		end
	end
	
	
	
	
	
	
	
	
	
	
	
	
	
end
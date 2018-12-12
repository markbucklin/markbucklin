classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		Controllable < ignition.core.Task
	
	
	% CONTROL
	properties
	end
	
	
	properties (SetAccess = protected)
		Control @ignition.core.TaskInterface		
		ControlUpdateTask @ignition.core.Task
	end
	
	properties (Constant)
		PropertyTag = 'CONTROL'
	end
	
	
	
	
	methods
		function obj = Controllable( fcn )
			import ignition.core.TaskInterface						
			updateTask = ignition.core.Task( fcn );
			obj.ControlUpdateTask = updateTask;						
			tag = 'CONTROL';
			obj.Control = TaskInterface.buildFromPropTag( obj, tag, updateTask);
			
		end
	end
	
	
	
	
	
	
	
	
	
	
	
	
	
end
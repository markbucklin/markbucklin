classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		Configurable < ignition.core.Task
	
	
	% CONFIGURATION
	properties
	end
	
	properties (SetAccess = protected)
		Configuration @ignition.core.TaskInterface
		ConfigTask @ignition.core.Task
	end
	
	
	
	
	methods
		function obj = Configurable( fcn )			
			import ignition.core.TaskInterface						
			updateTask = ignition.core.Task( fcn );
			obj.ConfigTask = updateTask;			
			tag = 'CONFIGURATION';
			obj.Configuration = TaskInterface.buildFromPropTag( obj, tag, updateTask);			
			
		end
	end
	
	
	
	
	
	
	
	
	
	
	
	
	
end
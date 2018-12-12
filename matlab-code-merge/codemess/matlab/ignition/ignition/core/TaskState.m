classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		TaskState ...
		< ignition.core.TaskData
	
	

	
	
	
	
	
	
	
		methods
			function obj = TaskState( task )
				
				controlStruct = getStructFromPropGroup(task, 'STATE');
				names = fields(controlStruct);
				vals = struct2cell(controlStruct);				
				obj = obj@ignition.core.TaskData( task, names, vals );
				
			end
		end
	
		
		
	
	
	
end
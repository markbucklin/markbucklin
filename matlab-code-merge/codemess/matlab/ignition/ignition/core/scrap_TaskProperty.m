classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		TaskProperty ...
		< ignition.core.tasks.TaskIO
	
	
	% TASK I/O
	properties (SetAccess = immutable)
		PropertyName
		%ParentStructure
	end
	
	
	
	
	
	
	methods
		function obj = TaskProperty(genTask, src, prop, val)
			
			% CONSTRUCT A TASK-IO (LINKABLE) OBJECT
			obj = obj@ignition.core.tasks.TaskIO( genTask);
			
			% ASSIGN NAME OF LINKABLE PROPERTY
			obj.PropertyName = prop;
			
			% ASSIGN DEFAULT INITIAL VALUE
			if nargin < 4
				val = src.(prop);
			end
			
			% INITIALIZE DATA
			obj.Data = val;
			
		end
	end
	
	methods (Static)
		
		% todo -> addTaskConfig( task, 'configName','initialVal')
		% todo -> dynamicprops
	end
	
	
	
	
	
	
	
end

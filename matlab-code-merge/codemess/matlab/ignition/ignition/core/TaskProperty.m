classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		TaskProperty ...
		< ignition.core.tasks.TaskIO
	
	
	% TASK I/O
	properties (SetAccess = immutable)
		PropertyName
		%ParentStructure
	end
	
	
	
	
	
	
	methods
		function obj = TaskProperty(src, prop, val)
			
			% CONSTRUCT A TASK-IO (LINKABLE) OBJECT
			obj = obj@ignition.core.tasks.TaskIO( src );
			
			% ASSIGN NAME OF LINKABLE PROPERTY
			obj.PropertyName = prop;
			
			% ASSIGN DEFAULT INITIAL VALUE
			if nargin < 3
				val = [];%src.(prop);
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

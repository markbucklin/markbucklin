classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		TaskControl ...
		< ignition.core.TaskData
	
	
	
	properties (SetAccess = immutable)
		%PropertyName
		%PropertyList		
	end
		
		
		methods
			function obj = TaskControl( task )%(prop, val, task, idx)								
				
				
				controlStruct = getStructFromPropGroup(task, 'CONTROL');
				names = fields(controlStruct);
				vals = struct2cell(controlStruct);
				
				obj = obj@ignition.core.TaskData( task, names, vals );
				
				% 				obj = obj@ignition.core.tasks.TaskIO( task, 1);
				%
				% 				if nargin < 2
				% 					controlStruct = getStructFromPropGroup(task, 'CONTROL');
				% 					names = fields(controlStruct);
				% 					vals = struct2cell(controlStruct);
				% 				elseif nargin < 3
				% 					vals = cell(1,numel(names));
				% 				end
				%
				% 				k = numel(names);
				% 				while k < numel(names)
				% 					k = k + 1;
				% 					obj.PropertyList(k) = ignition.core.TaskProperty(...
				% 						names{k}, vals{k} , task, k);
				% 					link(obj, obj.PropertyList(k));
				% 				end
				
				
				
				% 				obj = obj@ignition.core.tasks.TaskIO( task, idx);
				%
				% 				obj.PropertyName = prop;
				% 				obj.Data = val;
				
			end
		end
	
	methods (Static)
		
	end
	
	
	
	
	
	
	
end

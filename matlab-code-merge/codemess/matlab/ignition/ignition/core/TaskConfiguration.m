classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		TaskConfiguration ...
		< ignition.core.TaskData
	
	
	
	properties (SetAccess = immutable)
		%PropertyList
	end
	
	
	methods
		function obj = TaskConfiguration(task)
			
			controlStruct = getStructFromPropGroup(task, 'CONFIGURATION');
			names = fields(controlStruct);
			vals = struct2cell(controlStruct);
			
			obj = obj@ignition.core.TaskData( task, names, vals );
			
			
		end
	end
	
	methods (Static)
		
		% todo -> addTaskConfig( task, 'configName','initialVal')
		% todo -> dynamicprops
	end
	
	
	
	
	
	
	
end







% 				obj = obj@ignition.core.tasks.TaskIO( task, 1);
%
% 				if nargin < 2
% 					configStruct = getStructFromPropGroup(task, 'CONFIGURATION');
% 					names = fields(configStruct);
% 					vals = struct2cell(configStruct);
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




%obj.PropertyName = prop;
%obj.Data = val;

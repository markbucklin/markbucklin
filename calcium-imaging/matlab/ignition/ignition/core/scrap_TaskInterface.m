classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		TaskInterface ...
		< ignition.core.Task
	
	% dynamicprops (todo)
	
	
	% TASK I/O
	properties (SetAccess = immutable)		
		PropertyList @ignition.core.TaskProperty	
		PropertyMap @containers.Map
	end
	
	properties (Constant)		
	end
	
	
	
	methods
		function obj = TaskInterface( taskUpdate, taskSrc, names, vals)
			
			obj = obj@ignition.core.Task( taskUpdate );
			% todo -> create mutual listener task that updates Data
			
			assert(iscellstr(names))
			if nargin < 4
				vals = cell(1,numel(names));
			end
			
			propMap = containers.Map;			
			
			k = 0;
			while k < numel(names)
				k = k + 1;
				name = names{k};
				val = vals{k};								
				propLink = ignition.core.TaskProperty( taskUpdate, taskSrc, name, val);				
				
				% ADD TO ARRAY OF TASK-PROPERTY OBJECTS
				obj.PropertyList(k) = propLink;
				
				% ADD TO HASH-MAP
				if ~isKey(propMap, name)
					propMap(name) = propLink;
				else
					propMap(name) = [propMap(name) ; propLink];
				end
								
			end
			obj.PropertyMap = propMap;
			
			% INITIALIZE DATA
			obj.Data = cell2struct( vals(:), names(:));
			
		end		
	end
	methods (Access = private)
		function S = updateStruct(obj, varargin)
			
		end
		
	end
	
	
	methods (Static)
		function taskDataObj = buildFromPropTag( propSrc, tag, updateTask)
			
			controlStruct = getStructFromPropGroup(propSrc, tag);
			fprintf('Building TaskInterface object using property tag: <strong>%s</strong>\n',tag)
			names = fields(controlStruct);
			vals = struct2cell(controlStruct);
			fprintf('\t%s\n',names{:});			
			taskDataObj = ignition.core.TaskInterface( updateTask, propSrc, names, vals );
			
		end
	end
	
	
	
	
	
	
	
	
	
end
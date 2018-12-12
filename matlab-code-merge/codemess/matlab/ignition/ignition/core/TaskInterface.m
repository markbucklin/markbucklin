classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		TaskInterface ...
		< ignition.core.Task
	%< ignition.core.Handle ...
	%& ignition.core.CustomDisplay
	
	% dynamicprops (todo)
	
	
	% TASK I/O
	properties (SetAccess = immutable)
		ParentTaskObj
		PropertyList @ignition.core.TaskProperty	
		PropertyMap @containers.Map
		PropertyStruct @struct
		NewPropertyDataListener @event.proplistener
	end
	
	properties (SetAccess = protected)
		IsLocked = false
	end
	
	
	
	methods
		function obj = TaskInterface( src, names, vals)
			
			obj = obj@ignition.core.Task( @ignition.shared.nullFcn );
			% todo -> create mutual listener task that updates Data
			
			propIoNewDataFcn = @(~,evnt)taskPropertyObjNewDataCallback(obj, evnt.AffectedObject);
			
			% CHECK INPUT			
			assert(iscellstr(names))
			if nargin < 3
				vals = cell(size(names));
				readValsFromSource = true;
			else
				readValsFromSource = false;
			end			
			assert( isa( src, 'ignition.core.Task') )
			% assert( isobject(src) || isstruct(src) )
			% todo -> create interface for multiple src structs reflected across workers
			
			% STORE HANDLE TO PARENT TASK OBJECT
			obj.ParentTaskObj = src;
			% todo assert isprop( src, names)
			
			% INITIALIZE EMPTY HASH-MAP
			propMap = containers.Map;			
			
			k = 0;
			while k < numel(names)
				k = k + 1;
				
				% GET NAME OF PROPERTY TO ADD TO INTERFACE
				name = names{k};
				
				% GET CURRENT VALUE OF PROPERTY FROM INPUT OR DIRECTLY FROM SOURCE
				if readValsFromSource
					val = src.(name);
					vals{k} = val;
				else
					val = vals{k};
				end
				
				% CONSTRUCT 'TASK-PROPERTY' OBJECT (LINKABLE TO OTHER TASK-IO OBJECTS)
				taskPropObj = ignition.core.TaskProperty( src, name, val);				
				
				% ADD TO ARRAY OF TASK-PROPERTY OBJECTS
				obj.PropertyList(k) = taskPropObj;
				
				% ADD TO HASH-MAP
				if ~isKey(propMap, name)
					propMap(name) = taskPropObj;
				else
					propMap(name) = [propMap(name) ; taskPropObj];
				end
				
				% MAKE POST-SET LISTENER TO UPDATE SRC-PROPERTY FROM TASK-PROPERTY-OBJ
				obj.NewPropertyDataListener(k) = addlistener( ...
					taskPropObj, 'Data', 'PostSet', propIoNewDataFcn);
				
				% MAKE PRE-GET LISTENER TO READ FROM SOURCE
				%obj.NewPropertyDataListener(k) = addlistener( ...					
				%	taskPropObj, 'Data', 'PostSet', propIoNewDataFcn);
								
			end
			
			% ASSIGN/STORE FULL HASH MAP TO PROPERTY
			obj.PropertyMap = propMap;
			
			% MAKE STRUCTURE OF REPRESENTING SUBSET OF PROPERTIES PROVIDED BY THIS INTERFACE
			initialPropStruct = cell2struct( vals(:), names(:));
			obj.PropertyStruct = initialPropStruct;
			
			% CONSTRUCT SINGLE INPUT & OUTPUT FOR INTERFACING WITH FUNCTIONS THAT UPDATE USING STRUCT
			obj.NumInputArguments = 1;
			obj.NumOutputArguments = 1;
			obj.Input = ignition.core.TaskInput(obj,1);
			obj.Output = ignition.core.TaskOutput(obj,1);
			obj.Input.Data = initialPropStruct;
			obj.Output.Data = initialPropStruct;
			
		
			
			
		end		
		function lock(obj)
			if numel(obj) == 1
				obj.IsLocked = true;
			elseif numel(obj) > 1
				[obj.IsLocked] = deal(true);
			end			
			
			% todo -> disable all listeners 
			
		end
		function unlock(obj)
			if numel(obj) == 1
				obj.IsLocked = false;
			elseif numel(obj) > 1
				[obj.IsLocked] = deal(false);
			end			
		end
	end
	methods (Access = protected)
		function taskPropertyObjNewDataCallback(obj, taskPropObj)
			% evnt.AffectedObject -> TaskProperty object whos property 'Data' was just set
			try
				name = taskPropObj.PropertyName;
				val = taskPropObj.Data;
				
				% UPDATE PROPERTY STRUCTURE STORED BY TASK-INTERFACE
				obj.PropertyStruct.(name) = val;
				
				% UPDATE PROPERTY VALUE IN PARENT (TASK) OBJECT
				task = obj.ParentTaskObj;
				% or task = taskPropObj.TaskObj;
				task.(name) = val;
				
				% todo -> submit message to datalogger class
				
			catch me
				msg = getReport(me);
				disp(msg)
			end
			
		end
		function taskStructureInputNewDataCallback(obj, taskInputObj)
			% todo
		end
		
	end
	
	
	methods (Static)
		function taskDataObj = buildFromObjectPropertyGroup( propSrc, tag)
			
			controlStruct = getStructFromPropGroup(propSrc, tag);
			fprintf('Building TaskInterface object using property tag: <strong>%s</strong>\n',tag)
			names = fields(controlStruct);
			vals = struct2cell(controlStruct);
			fprintf('\t%s\n',names{:});
			taskDataObj = ignition.core.TaskInterface( propSrc, names, vals );
			
		end
	end
	
	
	
	
	
	
	
	
	
end


function handlePropEvent(src,evnt)
%
% src		-> a meta.property object describing the object that is the source of the property event
%			Name: 'Data'
%			Description: ''
%			DetailedDescription: ''
%			GetAccess: 'public'
%			SetAccess: 'public'
%			Dependent: 0
%			Constant: 0
%			Abstract: 0
%			Transient: 0
%			Hidden: 0
%			GetObservable: 1
%			SetObservable: 1
%			AbortSet: 0
%			NonCopyable: 0
%			GetMethod: []
%			SetMethod: []
%			HasDefault: 0
%			DefiningClass: [1x1 meta.class] -> 'ignition.core.tasks.TaskIO'
%
%
% evnt	-> event.PropertyEvent object containing information about the event
%			EventName — One of the four event names listed in the Description section
%			Source — meta.property object that triggers the event
%			AffectedObject — The object whose property is affected.

end







classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		MultiLinkedTaskIOWrapper ...
		< ignition.core.tasks.TaskIO
	
	
	
	
	properties (SetAccess=protected, Hidden)
		EncapsulatedTaskIOObj @ignition.core.tasks.TaskIO
		IsSplit = false
		IsJoin = false
	end
	
	
	
	methods
		function obj = MultiLinkedTaskIOWrapper( taskio)
			% MultiLinkedTaskIOWrapper - Split/Join wrapper for multiple TaskIO objects
			
			task = [taskio.TaskObj];
			idx = [taskio.Idx];
			
			% numObj = numel(task);
			% assert numtask=numidx (todo)
			
			% SUPERCLASS CONSTRUCTOR
			obj = obj@ignition.core.tasks.TaskIO( task, idx);
			
			% ASSIGN INPUT TASKIO TO LOCAL PROPERTY
			obj.EncapsulatedTaskIOObj = taskio;
			
			% ALSO COPY LINKED IO FROM LIST
			linkedIO = [taskio.LinkedIO];
			% assert unique?
			if ~isempty(linkedIO)
				obj.LinkedIO = linkedIO;
			end
			
			% REASSIGN BI-DIRECTIONAL LINK TO SELF (WRAPPER)
			linkedIO.LinkedIO = obj;
			
			% CHECK TYPE:   INPUT->SPLIT   OUTPUT->JOIN
			if isa(taskio, 'ignition.core.TaskInput')
				obj.IsSplit = true;
			else
				obj.IsJoin = true;
			end
			
		end
		%function link(obj, varargin)
			
		%end
		
	end
	
	
	
	
	
	
	
	
	
	
end

classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		TaskIO ...
		< ignition.core.UniquelyIdentifiable ...
		& ignition.core.CustomDisplay ...
		& ignition.core.Handle ...
		& matlab.mixin.Heterogeneous		
	
	
	
	% TASK I/O
	properties (SetObservable,GetObservable)
		IsLinked = false 
	end
	properties (SetAccess=protected)
		TaskObj @ignition.core.Handle		
	end
	properties (SetObservable,GetObservable)
		Data
	end
	
	properties (SetAccess=protected, Hidden)
		Source @ignition.core.tasks.TaskIO
		Target @ignition.core.tasks.TaskIO
		LinkedIO @ignition.core.tasks.TaskIO		
	end
	
	
	
	
	methods
		function obj = TaskIO( task, idx)
			% TaskIO - Parent class representing input and output arguments for a Task
			
			if nargin > 0
				obj.TaskObj = task;
			end
			if nargin > 1
				obj.Idx = idx;
			end
			
		end
		% 		function link( ioSource, ioTarget)
		%
		% 			% CHECK IF EITHER IS NON-SCALAR
		%
		%
		% 			% CHECK IF EITHER ALREADY HAS TASKIO LINKS
		%
		% 			% ioSource = [ioSource(:) ; ioTarget.LinkedIO];
		%
		%
		%
		%
		% 			% ASSIGN BIDIRECTIONAL LINK BETWEEN SOURCE & TARGET
		% 			ioSource.LinkedIO = [ioSource.LinkedIO , ioTarget];
		% 			ioTarget.LinkedIO = [ioTarget.LinkedIO , ioSource];
		% 			%ioSource.LinkedIO = ioTarget;
		% 			%ioTarget.LinkedIO = ioSource;
		%
		% 			ioSource.IsLinked = true;
		% 			ioTarget.IsLinked = true;
		%
		% 			% RECORD IN CURRENT TASK GRAPH
		%
		%
		% 		end
		
	end
	
	
	
	
	
	
	
	
	
	
end



		

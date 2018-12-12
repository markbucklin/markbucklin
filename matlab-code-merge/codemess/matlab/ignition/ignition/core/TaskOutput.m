classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		TaskOutput ...
		< ignition.core.tasks.FunctionArgument
	
	
	
	
	properties (SetAccess = protected)		
		IsReplicated = false
	end
	
	
	
	events
		SpaceAvailable % or should be property?
	end
	
	
	methods
		% CONSTRUCTOR
		function obj = TaskOutput( task, idx)
			% TaskOutput - Represents output arguments for a Task Object
			% obj = obj@ignition.core.tasks.TaskIO(task);
			% 			if nargin > 1
			% 				% ASSIGN SPECIFIED IDX
			% 				obj.Idx = idx;
			% 			else
			% 				% GROW BY ONE
			% 				obj.Idx = numel( task.Output ) + 1;
			% 			end
			
			if nargin < 2
				idx = numel(task.Output) + 1;
			end
			
			obj = obj@ignition.core.tasks.FunctionArgument( task, idx);
			
		end
		
	end
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
end






% LINK A SOURCE (OUTPUT) TO A TARGET (INPUT)
% 		function link( ioSource, ioTarget)
%
% 			% ASSERT TARGET IS VALID INPUT
% 			assert( isa(ioTarget, 'ignition.core.tasks.TaskIO') )
%
% 			% CHECK IF SOURCE IS NON-SCALAR -> CALL RECURSIVELY
% 			if ~isscalar(ioSource)
% 				assert( numel(ioSource)==numel(ioTarget) )
% 				for k=1:numel(ioSource)
% 					link( ioSource(k), ioTarget(k) )
% 				end
% 				return
%
% 			else
% 				% ASSIGN BIDIRECTIONAL LINK BETWEEN SOURCE & TARGET
% 				ioSource.Target = [ioSource.Target , ioTarget];
% 				ioTarget.Source = [ioTarget.Source , ioSource];
%
% 				% ASSIGN UNIDIRECTIONAL LINK
% 				ioSource.LinkedIO = [ioSource.LinkedIO , ioTarget];
%
% 				ioSource.IsLinked = true;
% 				ioTarget.IsLinked = true;
%
% 				% RECORD IN CURRENT TASK GRAPH
%
% 			end
%
% 		end

%obj = obj@ignition.core.tasks.TaskIO(task,idx);


% 	% TASK I/O
% 	properties (Dependent)
% 		Target
% 	end

% 	methods
% 		function linkio = get.Target(obj)
% 			linkio = obj.LinkedIO;
% 		end
% 	end
%



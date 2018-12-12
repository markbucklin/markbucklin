classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		TaskInput ...
		< ignition.core.tasks.FunctionArgument
	
	
	
	
	properties (SetAccess = protected)		
		IsConsumed = false % opposite of IsReused
		IsConstant = false % IsSetOnce
		IsRead = false		
	end
	
	
	events
		DataAvailable% or should be property?
	end
	
	
	methods
		% CONSTRUCTOR
		function obj = TaskInput( task, idx)
			% TaskInput - Represents input arguments for a Task Object
			% 			obj = obj@ignition.core.tasks.TaskIO(task);
			% 			if nargin > 1
			% 				% ASSIGN SPECIFIED IDX
			% 				obj.Idx = idx;
			% 			else
			% 				% GROW BY ONE
			% 				obj.Idx = numel( task.Input ) + 1;
			% 			end
			if nargin < 2
				idx = numel(task.Input) + 1;
			end
			
			obj = obj@ignition.core.tasks.FunctionArgument( task, idx);
			
		end
		function avail = available(obj)
			
			% CHECK IF TASK INPUT IS DECLARED CONSTANT
			isConst = logical(obj.IsConstant);
			
			% CHECK IF DATA PROP HAS BEEN FILLED
			if numel(obj) == 1
				hasData = ~isempty(obj.Data);
			else
				hasData = ~cellfun(@isempty, {obj.Data});
			end
			
			% isReq = [obj.IsRequired];
			isAsync = ~[obj.IsConsumed];
			isFresh = ~[obj.IsRead];
			
			
			avail = hasData && (isConst || isFresh || isAsync);
			
			
			% todo -> or if constant
			% or check pointer from source
			
		end
		function makeConstant(obj)
			[obj.IsConstant] = deal(true);
			[obj.IsConsumed] = deal(false);
		end
		function makeSynchronous(obj)
			[obj.IsConsumed] = deal(true);
			[obj.IsConstant] = deal(false);
		end
		function makeAsync(obj)
			[obj.IsConsumed] = deal(false);
		end
		
	end
	
	
	
	
	
	
	
	
	
	
	
	
end






% LINK A TARGET (INPUT) TO A SOURCE (OUTPUT)
% 		function link( ioTarget, ioSource)
%
% 			% ASSERT SOURCE IS VALID INPUT
% 			assert( isa(ioSource, 'ignition.core.tasks.TaskIO') )
%
% 			% CHECK IF TARGET IS NON-SCALAR -> CALL RECURSIVELY
% 			if ~isscalar(ioTarget)
% 				assert( numel(ioSource)==numel(ioTarget) )
% 				for k=1:numel(ioSource)
% 					link( ioTarget(k) , ioSource(k) )
% 				end
% 				return
%
% 			else
% 				% ASSIGN BIDIRECTIONAL LINK BETWEEN SOURCE & TARGET
% 				ioSource.Target = [ioSource.Target , ioTarget];
% 				ioTarget.Source = [ioTarget.Source , ioSource];
%
% 				% ASSIGN UNIDIRECTIONAL LINK (todo: unnecessary??)
% 				ioTarget.LinkedIO = [ioTarget.LinkedIO , ioSource];
%
% 				ioSource.IsLinked = true;
% 				ioTarget.IsLinked = true;
%
% 				% RECORD IN CURRENT TASK GRAPH
%
% 			end
%
% 		end





% 	% TASK I/O
% 	properties (Dependent)
% 		Source
% 	end


% 	methods
% 		function linkio = get.Source(obj)
% 			linkio = obj.LinkedIO;
% 		end
% 	end
%

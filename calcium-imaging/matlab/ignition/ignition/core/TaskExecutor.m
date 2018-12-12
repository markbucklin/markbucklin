classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		TaskExecutor < ignition.core.Object & handle
	
	
	
	
	
	
	
	
	
	properties
		SequentialTaskList
		ConcurrentTaskList
	end
	% FUNCTION HANDLES
	properties (SetAccess = protected)
		DataAvailableFcn @function_handle
		DataWrittenFcn @function_handle
	end
	
	% INPUT/OUTPUT
	properties (SetAccess = protected)
		StreamInputBuffer @ignition.core.Buffer
		StreamOutputBuffer @ignition.core.Buffer
	end
	
	% todo -> 
	%		PerformanceMonitorObj
	
	
	% ##################################################
	% EVENTS
	% ##################################################
	events (NotifyAccess = ?ignition.core.Object)		
		Ready
		InputDataAvailable
		Processing
		OutputDataAvailable
		Finished
		Error
	end

	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
end














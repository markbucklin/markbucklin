classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		ConstantTaskData ...
		< ignition.core.TaskData
	
	% TaskDataSubmission
	% TaskDataRetrieval
	% WriteOnceData
	%todo
	
	
	properties (Constant)
	end
	
	
	
	methods
		function obj = ConstantTaskData(data, varargin)
			
			obj = obj@ignition.core.TaskData(varargin{:});
			
			% use data structure, or read from properties marked Constant
			obj.Data = data;
			
		end
		
		
		
	end
	
	
	
	
	
	
	
	
	
	
end
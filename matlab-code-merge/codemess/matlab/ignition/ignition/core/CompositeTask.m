classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		CompositeTask < ignition.core.Task
	
	
	
	
	
	
	
	
	
	
	
	
	properties (SetAccess = protected)
		Configuration @struct
		Cache @struct
		ConfigurationInputProperties @cell
	end
	
	
	methods
		function obj = CompositeTask( numInputs, numOutputs )
			
			if nargin>0
				obj.NumInputArguments = numInputs;
				if nargin > 1
					obj.NumOutputArguments = numOutputs;
				end
			end
			
		end
	end
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
end
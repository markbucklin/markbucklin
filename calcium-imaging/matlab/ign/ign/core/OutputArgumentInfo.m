classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		OutputArgumentInfo ...
		< ign.core.ArgumentInfo ...
		& matlab.mixin.Heterogeneous
	
	
	
	
	properties (SetAccess = protected)
		MatchingInput
	end
	
	
	
	methods
		function obj = OutputArgumentInfo(varargin)
			obj = obj@ign.core.ArgumentInfo( varargin{:})
			obj.IOType = 'out';
		end
		function bindMatchingInput(obj,inputObj)
			obj.MatchingInput = inputObj;
		end
	end
	
	
	
	
	
end
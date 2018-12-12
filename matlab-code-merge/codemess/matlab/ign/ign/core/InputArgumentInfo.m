classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		InputArgumentInfo ...
		< ign.core.ArgumentInfo ...
		& matlab.mixin.Heterogeneous
	
	
	
	
	properties (SetAccess = protected)
		MatchingOutput
	end
	
	
	
	methods
		function obj = InputArgumentInfo(varargin)
			obj = obj@ign.core.ArgumentInfo( varargin{:})
			obj.IOType = 'in';
		end
		function bindMatchingOutput(obj,outputObj)
			obj.MatchingOutput = outputObj;
		end
	end
	
	
	
	
	
end
classdef (CaseInsensitiveProperties, TruncatedProperties, HandleCompatible)...
		DataArrayReference ...
		< ignition.core.type.DataArray ...
		& ignition.core.Handle 
% 	...
% 		& matlab.mixin.Heterogeneous
	
	
	
	
	
	
	
	
	
	
	
	methods
		function obj = DataArrayReference(varargin)
			obj = obj@ignition.core.type.DataArray(varargin{:});
		end
	end
	
	
	
	
	
end
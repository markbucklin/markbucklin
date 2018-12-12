classdef (HandleCompatible) DataObject < ign.core.Object
	
	
	
	properties
		Value
	end
	
	
	
	methods
		function obj = DataObject(value)
			if nargin
				obj.Value = value;
			end
		end
	end
	
	
	
	
	
	
end
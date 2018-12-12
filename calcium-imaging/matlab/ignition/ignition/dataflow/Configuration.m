classdef Configuration < ignition.core.Object & handle
	
	
	
	
	
	
	
		properties (SetAccess = protected)
			Function @function_handle
		end
		properties (SetAccess = protected, SetObservable)
			Output @struct
		end
		
		
		
		
		methods
			function obj = Configuration(varargin)
				
				if nargin
					parseConstructorInput(obj, varargin{:});
				end
					
			end
		end
	
	
	
	
	
	
	
	
	
	
end
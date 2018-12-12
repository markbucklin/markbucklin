classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		TiffFileStream < ignition.io.FileStream
	
	

	
	
	
	methods
		function obj = TiffFileStream(varargin)
						
			% CONFIGURE (QUERY USER - RUN IN CLIENT)
			obj.ConfigureFcn = @ignition.io.tiff.configureTiffFileStream;			
			
			% INITIALIZE (USE FIRST INPUT TO INITIALIZE ANY OTHER PARAMETERS)
			obj.InitializeFcn = @ignition.io.tiff.initializeTiffFileStream;
			
			% MAIN TASK
			obj.CachePreUpdateFcn = @ignition.io.tiff.preUpdateTiffFileStream;
			obj.MainOperation = ignition.core.Operation(@ignition.io.tiff.readTiffFileStream, 1, 4);
					
			
			% RE-DEFINE PROPERTIES WITH ANY EXTRA CONSTRUCTION ARGUMENTS
			if nargin
				parseConstructorInput(obj, varargin{:});
			end
			
		end
		
		
	end
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
end
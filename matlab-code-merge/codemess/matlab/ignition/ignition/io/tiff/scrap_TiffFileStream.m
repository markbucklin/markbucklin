classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		TiffFileStream < ignition.io.FileStream
	
	
	
% 	% CONFIGURATION
% 	properties
% 		FileInputObj @ignition.io.FileWrapper
% 		ParseFrameInfoFcn @function_handle		
% 	end
% 	
% 	% MODIFIABLE STATE
% 	properties
% 		FirstFrameIdx
% 		NextFrameIdx
% 		LastFrameIdx
% 		NumFramesPerRead
% 	end
% 	
% 	% READ-ONLY CACHE PROPERTIES
% 	properties (SetAccess = ?ignition.core.Task)
% 		StreamFinishedFlag @logical
% 	end
	
	
	
	
	
	methods
		function obj = TiffFileStream(varargin)
						
			% NAME
			obj.Name = 'TiffFileStream';
			
			% CONFIGURE (QUERY USER - RUN IN CLIENT)
			obj.ConfigureTaskFcn = @ignition.io.tiff.configureTiffFileStream;
			obj.ConfigurationInputProperties = {'FileInputObj','ParseFrameInfoFcn'};
			
			% INITIALIZE (USE FIRST INPUT TO INITIALIZE ANY OTHER PARAMETERS)
			obj.InitializeTaskFcn = @ignition.io.tiff.initializeTiffFileStream;
			
			% MAIN TASK
			obj.PreMainTaskFcn = @ignition.io.tiff.preUpdateTiffFileStream;
			obj.MainTaskFcn = @ignition.io.tiff.readTiffFileStream;
					
			
			% RE-DEFINE PROPERTIES WITH ANY EXTRA CONSTRUCTION ARGUMENTS
			if nargin
				parseConstructorInput(obj, varargin{:});
			end
			
		end
		
		
	end
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
end
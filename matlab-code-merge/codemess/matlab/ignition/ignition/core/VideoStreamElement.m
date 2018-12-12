classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		VideoStreamElement < ignition.core.type.VideoFrame & ignition.core.BufferElement
	
	

	
	
	
	methods
		function obj = VideoStreamElement(varargin)
			
			obj = obj@ignition.core.type.VideoFrame(varargin{:});
			
		end
	end
	
	
	
	
	
end

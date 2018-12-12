classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		VideoFrameReference < ignition.core.type.VideoFrame & handle
	
	
% todo: add Performance monitor that tracks latency and throughput by ticking reads
	
	
	
	properties (Hidden, Access = protected)
		IsOwner @logical
		OwnerReference @ignition.core.type.VideoFrameReference
		ChannelIdx
		FrameIdx
	end % todo
	
	
	
	
	
	
	methods
		function obj = VideoFrameReference(varargin)
						
			obj = obj@ignition.core.type.VideoFrame(varargin{:});
			
		end
	end
	
	
	
	
	
end

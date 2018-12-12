classdef (CaseInsensitiveProperties = true) VideoSizeReference < imref2d
	% VideoSizeReference
	
	
	
	
	
	
	properties
		FrameSize
		NumRows
		NumCols
		NumChannels
		NumFrames
		NumPixels
	end
	properties
		TimeDimension
		ChannelDimension
	end
	properties (SetAccess = protected)
		DataType
		IsOnGpu
		RowSubs
		ColSubs
		FrameSubs
		ChanSubs
	end
	properties (SetAccess = protected, Hidden)
		ZeroNativeType
		ZeroDoubleType
	end
	
	
	
	
	
	
	
	
	
	
	
	
	
	methods
		function obj = VideoSizeReference(vid, varargin)
			
			% GET INPUT DIMENSIONS
			[numRows, numCols, dim3, dim4] = size(vid);
			
			% DETERMINE TIME DIMENSION AND NUMBER OF CHANNELS
			numDims = ndims(vid);
			if numDims <= 3
				timeDim = 3;
				channelDim = 4;
				numFrames = dim3;
				numChannels = 1;
			else
				if dim3 <= dim4
					timeDim = 4;
					channelDim = 3;
					numChannels = dim3;
					numFrames = dim4;
				else
					timeDim = 3;
					channelDim = 4;
					numChannels = dim4;
					numFrames = dim3;
				end
			end
			numPixels = numRows*numCols*numChannels;
			
			% CALL BUILT-IN PARENT CLASS CONSTRUCTOR
			imSizeParent = [numRows, numCols, numFrames];
			obj = obj@imref2d(imSizeParent, varargin{:});
			
			% SET UP FRAME SIZE (DISTINCT FROM IMAGE SIZE)
			zeroNative = zeros(1,'like',vid);
			zeroDouble = double(zeroNative);
			obj.FrameSize =			int32( zeroDouble + [numRows, numCols, numChannels]);
			obj.TimeDimension = timeDim;
			obj.ChannelDimension = channelDim;
			if isa(vid, 'gpuArray') && existsOnGPU(vid)
				obj.DataType = classUnderlying(vid);
				obj.IsOnGpu = true;
			else
				obj.DataType = class(vid);
				obj.IsOnGpu = false;
			end
			
			% MAKE LOCAL TYPES GPU-COMPATIBLE
			obj.NumRows =				int32( zeroDouble + numRows);
			obj.NumCols =				int32( zeroDouble + numCols);
			obj.NumChannels =		int32( zeroDouble + numChannels);
			obj.NumFrames =			int32( zeroDouble + numFrames);
			obj.NumPixels =			int32( zeroDouble + numPixels);
			
			% STORE TYPES FOR EASY CONVERSION/TRANSFER TO GPU WHEN RECALCULATING SUBSCRIPTS
			obj.ZeroNativeType = zeroNative;
			obj.ZeroDoubleType = zeroDouble;
			
			% CONSTRUCT ORIENTED SUBSCRIPTS (FOR CALLS TO ARRAYFUN)
			% 			obj = constructOrientedSubscripts(obj);
			
			
		end
		function varargout = getDimensions(obj)
			
			if nargout == 1
				% PLACE IN STRUCTURE
				dim.rows = obj.NumRows;
				dim.cols = obj.NumCols;
				dim.frames = obj.NumFrames;
				dim.chans = obj.NumChannels;
				varargout{1} = dim;
				
			elseif nargout > 1
				% ALSO MAKE AVAILABLE AS COMMA SEPARATED LIST OUTPUT
				argsOut = num2cell(ones(1,nargout,'like',obj.NumRows));
				argsOut{1} = obj.NumRows;
				argsOut{2} = obj.NumCols;
				argsOut{obj.FrameDimension} = obj.NumFrames;
				argsOut{obj.ChannelDimension} = obj.NumChannels;
				varargout = argsOut(1:nargout);
				
			end
		end
		function varargout = getSubscripts(obj, flagUpdate)
			
			% UPDATE SUBSCRIPTS
			if nargin < 2
				flagUpdate = [];
			end
			if isempty(flagUpdate)
				flagUpdate = ~isempty(obj.RowSubs);
			end
			if flagUpdate
				obj = constructOrientedSubscripts(obj);
			end
			
			% PLACE IN STRUCTURE
			subs.rows = obj.RowSubs;
			subs.cols = obj.ColSubs;
			subs.frames = obj.FrameSubs;
			subs.chans = obj.ChanSubs;
			
			% ALSO MAKE AVAILABLE AS COMMA SEPARATED LIST OUTPUT
			if nargout == 1
				varargout{1} = subs;
			elseif nargout > 1
				argsOut = num2cell(ones(1,nargout,'like',subs.rows));
				argsOut{1} = subs.rows;
				argsOut{2} = subs.cols;
				argsOut{obj.FrameDimension} = subs.frames;
				argsOut{obj.ChannelDimension} = subs.channels;
				varargout = argsOut(1:nargout);
			end
			
		end
		function obj = constructOrientedSubscripts(obj)
			% For updating subscripts e.g. after changing Time/Channel-Dimension properties
			zeroDouble = obj.ZeroDoubleType;
			obj.RowSubs =				int32( zeroDouble + (1:obj.NumRows)');
			obj.ColSubs =				int32( zeroDouble + (1:obj.NumCols));
			if obj.TimeDimension == 3
				obj.FrameSubs =		int32(reshape(1:obj.NumFrames, 1,1,obj.NumFrames, 1) + zeroDouble);
				obj.ChanSubs =		int32(reshape(1:obj.NumChannels, 1,1,1,obj.NumChannels) + zeroDouble);
			else
				obj.FrameSubs =		int32(reshape(1:obj.NumFrames, 1,1,1,obj.NumFrames) + zeroDouble);
				obj.ChanSubs =		int32(reshape(1:obj.NumChannels, 1,1,obj.NumChannels,1) + zeroDouble);
			end
		end
	end
	methods
		function subs = get.RowSubs(obj)
			if isempty(obj.RowSubs)
				obj = constructOrientedSubscripts(obj);
			end
			subs = obj.RowSubs;
		end
		function subs = get.ColSubs(obj)
			if isempty(obj.ColSubs)
				obj = constructOrientedSubscripts(obj);
			end
			subs = obj.ColSubs;
		end
		function subs = get.FrameSubs(obj)
			if isempty(obj.FrameSubs)
				obj = constructOrientedSubscripts(obj);
			end
			subs = obj.FrameSubs;
		end
		function subs = get.ChanSubs(obj)
			if isempty(obj.ChanSubs)
				obj = constructOrientedSubscripts(obj);
			end
			subs = obj.ChanSubs;
		end
	end
	
	
	
	
	
	
	
	
	
end




























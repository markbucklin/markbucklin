classdef (CaseInsensitiveProperties, TruncatedProperties) GpuKernelCompanionFunctionWrapper < handle
	
	
	
	
	
	
	
	
	
	properties (SetAccess = protected)
		FcnName
		FcnHandle
		FcnInfo
		
		NumInputs
		NumOutputs
		
		OutputSize
		SupportsMultiChannel
		SupportsMultiFrame
		DimensionScalingEfficiency
	end
	properties (SetAccess = protected)
		RowDimension = 1
		ColumnDimension = 2
		ChannelDimension = 3
		FrameDimension = 4
	end
	properties (SetAccess = protected)
		InputSize
		NumPixels
	end
	properties (SetAccess = protected)
		NumRows
		NumColumns
		NumChannels
		NumFrames
	end
	properties (SetAccess = protected)
		RowSubs
		ColumnSubs
		ChannelSubs
		FrameSubs
	end
	
	
	
	
	
	
	
	
	
	
	
	
	methods
		function obj = GpuKernelCompanionFunctionWrapper(fcnName, varargin)
			
			if (nargin > 1) && ~isempty(varargin{1})
				obj = varargin{1};
			else
				obj.FcnName = fcnName;
				obj.FcnHandle = str2func(fcnName);
				% 				obj.FcnInfo = getcallinfo(fcnName);
			end
			
		end
		
		function [F,isNewSize] = checkInput(obj, F)
			
			% SIZE OF CURRENT INPUT			
			[numRows,numColumns,numChannels,numFrames] = size(F);
			inSize = [numRows,numColumns,numChannels,numFrames];
			
			% CHECK IF CURRENT INPUT MATCHES PRIOR INPUT
			if isempty(obj.InputSize)
				obj.InputSize = inSize;
				isNewSize = true;
			else
				isNewSize = prod(inSize(:)) ~= prod(obj.InputSize);
			end
			
			% UPDATE FUNCTION (TODO - WITH REWRITE) IF SIZE DOESN'T MATCH
			if isNewSize
				storeSize();
				storeSubscripts();
			end
			
			
			% SUBFUNCTIONS
			function storeSize()				
				obj.NumRows = numRows;
				obj.NumColumns = numColumns;
				obj.NumChannels = numChannels;
				obj.NumFrames = numFrames;
				obj.NumPixels = numel(F);
			end
			function storeSubscripts()				
				obj.RowSubs = int32(reshape(gpuArray.colon(1, numRows), numRows, 1));
				obj.ColumnSubs = int32(reshape(gpuArray.colon(1,numColumns), 1, numColumns));
				obj.ChannelSubs = int32(reshape(gpuArray.colon(1,numChannels), 1, 1, numChannels));
				obj.FrameSubs = int32(reshape(gpuArray.colon(1,numFrames), 1, 1, 1, numFrames));
			end
		end
		
		function [numRows,numColumns,numChannels,numFrames] = getInputSize(obj)
			numRows = obj.NumRows;
			numColumns = obj.NumColumns;
			numChannels = obj.NumChannels;
			numFrames = obj.NumFrames;
		end
		
		function [rowSubs, columnSubs, channelSubs, frameSubs] = getInputSubscripts(obj)
			rowSubs = obj.RowSubs;
			columnSubs = obj.ColumnSubs;
			channelSubs = obj.ChannelSubs;
			frameSubs = obj.FrameSubs;
		end
		
% 		function varargout = feval(obj, varargin)
% 			% 			varargout = feval(obj.
% 		end
	end
	
	
	
	
	
	
	
end































classdef (CaseInsensitiveProperties, TruncatedProperties, HandleCompatible)  VideoBaseType
	
	
	
	
	properties (Dependent)
		FrameData
		FrameTime
		FrameInfo
		FrameIdx
	end
	properties (SetAccess = protected)
		NumRows
		NumCols
		NumChannels
		NumFrames
	end
	properties (Access = protected, Hidden)
		pFrameData
		pFrameTime
		pFrameInfo
		pFrameIdx
	end
	properties (SetAccess = protected)
		DataType
	end
	
	
	
	
	% CONSTRUCTOR
	methods
		function obj = VideoBaseType(varargin)
			% >> obj = VideoBaseType(frameData)
			% >> obj = VideoBaseType(frameData, frameInfo)
			% >> obj = VideoBaseType(frameData, frameInfo, frameTime)
			% >> obj = VideoBaseType(frameData, frameInfo, frameTime, frameIdx)
			% >> obj = VideoBaseType(frameData, frameTime, frameInfo, frameIdx)
			%					(order of inputs doesn't matter)
			
			obj = parseConstructorInput(obj, varargin{:});
			
		end
	end
	methods (Access = protected, Hidden)
		function obj = parseConstructorInput(obj, varargin)
			
			% PARSE INPUT
			if nargin > 1
				for kArg = 1:numel(varargin)
					arg = varargin{kArg};
					if ~isempty(arg)
						if isstruct(arg)
							% -> FRAMEINFO
							obj.pFrameInfo = arg(:);
							
						elseif isnumeric(arg)
							argSize = size(arg);
							if all(argSize(1:2) > 1)
								% -> FRAMEDATA
								obj.pFrameData = arg;
								% 								frameData = arg;
								% 								obj.pFrameData = frameData;
								
							elseif isWholeNumber(arg)
								% -> FRAMEIDX
								obj.pFrameIdx = arg(:);
								
							else
								% -> FRAMETIME
								obj.pFrameTime = arg(:);
								
							end
						end
					end
				end
			end
			
			% ASSIGN DATA TO INTERNAL (HIDDEN) PROPERTY
			% 			obj.pFrameData = frameData;
			
			% GET INFORMATION ABOUT DATA (DIMENSIONS, TYPE, ETC)
			obj = updateFrameSize(obj);
			
			obj = updateDataType(obj);
			
			function flag = isWholeNumber(vec)
				rvecdiff = abs( sum( vec(:) - round(vec(:)) ));
				flag = rvecdiff < .001;
			end
			
		end
	end
	
	% CONVENIENCE METHODS - OVERLOADING METHODS SHARED FUNCTIONS
	methods
		function [numRows,numCols,numChannels] = getFrameSize(obj)
			if ~isempty(obj.pFrameData)
				numRows = obj.NumRows;
				numCols = obj.NumCols;
				numChannels = obj.NumChannels;
			else
				numRows = 0;
				numCols = 0;
				numChannels = 0;
			end
		end
		function numFrames = getNumFrames(obj)
			numFrames = obj.NumFrames;
		end
		function dataType = getPixelDataType(obj)
			dataType = obj.DataType;
		end
	end
	
	% INTERNAL UPDATE OF UNDERLYING DATA
	methods (Access = protected, Hidden)
		function obj = updateFrameSize(obj)
			frameData = obj.pFrameData;
			if ~isempty(frameData)
				% GET INFORMATION ABOUT DATA (DIMENSIONS, TYPE, ETC)
				numDims = ndims(frameData);
				if (numDims > 3)
					[numRows, numCols, numChannels, numFrames] = size(frameData);
				elseif (numDims < 3)
					[numRows, numCols] = size(frameData);
					numChannels = 1;
					numFrames = 1;
				else
					[numRows, numCols, dim3] = size(frameData);
					if (dim3 == 3)
						numChannels = 3;
						numFrames = 1;
					else
						numChannels = 1;
						numFrames = dim3;
						% 						frameData = reshape(frameData, numRows, numCols, numChannels, numFrames);
					end
				end
				obj.NumRows = numRows;
				obj.NumCols = numCols;
				obj.NumChannels = numChannels;
				obj.NumFrames = numFrames;
			end			
		end
		function obj = updateDataType(obj)
			if ~isempty(obj.pFrameData)
				if isa(obj.pFrameData, 'gpuArray')
					obj.DataType = classUnderlying(obj.pFrameData);
				else
					obj.DataType = class(obj.pFrameData);
				end
			else
				obj.DataType = '';
			end				
		end
		function obj = updateFrameData(obj)
			% 			frameData = reshape(frameData, numRows, numCols, numChannels, numFrames);
		end
		function obj = updateFrameIdx(obj)
			% todo
		end
		function obj = updateFrameTime(obj)
			% todo
		end
		function obj = updateFrameInfo(obj)
			% todo
		end
	end
	
	% GET METHODS FOR DEPENDENT PROPERTIES (over-ride in subclasses)
	methods
		function frameData = get.FrameData(obj)
			frameData = obj.pFrameData;
		end
		function frameInfo = get.FrameInfo(obj)
			frameInfo = obj.pFrameInfo;
		end
		function frameIdx = get.FrameIdx(obj)
			frameIdx = obj.pFrameIdx;
		end
		function frameTime = get.FrameTime(obj)
			frameTime = obj.pFrameTime;
		end		
	end
	
	% OVERLOAD BUILT-IN MATLAB FUNCTIONS
	methods
		function Fgpu = gpuArray(obj)
			Fgpu = gpuArray(obj.pFrameData);
		end
	end
	
	
	
	
	
	
	
	
end

classdef (CaseInsensitiveProperties, TruncatedProperties, HandleCompatible)  VideoSegment
	
	
	
	
	properties (Dependent)
		FrameData
		FrameTime
		FrameInfo
		FrameIdx
	end
	properties (Access = protected)
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
	
	
	
	
	
	methods
		function obj = VideoSegment(varargin)
			% >> obj = VideoSegment(frameData)
			% >> obj = VideoSegment(frameData, frameInfo)
			% >> obj = VideoSegment(frameData, frameInfo, frameTime)
			% >> obj = VideoSegment(frameData, frameInfo, frameTime, frameIdx)
			% >> obj = VideoSegment(frameData, frameTime, frameInfo, frameIdx)
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
								frameData = arg;
								obj.pFrameData = frameData;
								
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
					frameData = reshape(frameData, numRows, numCols, numChannels, numFrames);
				end
			end
			obj.NumRows = numRows;
			obj.NumCols = numCols;
			obj.NumChannels = numChannels;
			obj.NumFrames = numFrames;
			
			% ASSIGN DATA TO INTERNAL (HIDDEN) PROPERTY
			obj.pFrameData = frameData;
			
			function flag = isWholeNumber(vec)
				rvecdiff = abs( sum( vec(:) - round(vec(:)) ));
				flag = rvecdiff < .001;
			end
			
		end
		function obj = updateFrameData(obj)
			% todo
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
	
	
	methods
		function Fgpu = gpuArray(obj)
			Fgpu = gpuArray(obj.pFrameData);
		end
	end
	
	
	
	
	
	
	
	
end
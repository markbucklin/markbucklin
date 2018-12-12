classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		Buffer < handle %& matlab.mixin.Heterogeneous
	
	
	
	properties
		ChannelCapacity = 1
		FrameCapacity = 32
	end
	properties (SetAccess = protected)
		LastWriteIdx = 0
		LastReadIdx = 0
		FramesAvailableCount = 0
		SpaceAvailableCount
	end
	properties (SetAccess = protected)
		Block @ignition.core.BufferElement matrix
	end
	properties (Constant, Hidden)
		VariableCapacityIncrement = 32
	end
	properties (SetAccess = immutable)
		IsFixedCapacity @logical scalar = false
	end
	
	
	
	% INITIALIZATION
	methods
		function obj = Buffer(channelCapacity, frameCapacity, useFixed)
			% Use capacity argument to either specify an initial size, or a max size
			%
			%		Fixed FrameCapacity:
			%				>> obj = ignition.core.Buffer(32, true)
			%				>> obj = ignition.core.Buffer(inf)
			%
			%		Variable FrameCapacity:
			%				>> obj = ignition.core.Buffer(32, false)
			%				>> obj = ignition.core.Buffer(32)
			%				>> obj = ignition.core.Buffer()
			%
			
			initialFrameCapacity = obj.VariableCapacityIncrement;
			
			if nargin
				if (nargin > 2)
					try obj.IsFixedCapacity = useFixed; catch me, disp(me.message), end
				end
				if (nargin > 1)
					if isinf(frameCapacity)
						obj.IsFixedCapacity = false;
					else
						initialFrameCapacity = frameCapacity;
					end
					obj.FrameCapacity = frameCapacity;
				end
				if ~isempty(channelCapacity)
					obj.ChannelCapacity = channelCapacity;
				end
			end
			
			obj.Block(obj.ChannelCapacity, initialFrameCapacity) = ignition.core.BufferElement();
			obj.SpaceAvailableCount = initialFrameCapacity;			
			
		end
	end
	
	% GENERAL USE
	methods
		function write(obj, data)
			
			% GET CURRENT & REQUIRED ARRAY-SIZE			
			frameCap = size(obj.Block, 2);
			
			% NUMERIC ARRAY INPUT			
			numChannelsIn = ignition.shared.getNumChannels(data);
			numFramesIn = ignition.shared.getNumFrames(data);			
			fillCount = obj.FramesAvailableCount + numFramesIn;
			emptyCount = frameCap - fillCount;
			lastIdx = obj.LastWriteIdx;
			newLastIdx = lastIdx + numFramesIn;
			
			% GET INDEX INTO INTERNAL BUFFER-ELEMENT-ARRAY
			elementIdx = (lastIdx+1):newLastIdx;
			
			% EXTEND BUFFER (VARIABLE SIZE) OR LOOP INDICES (RING BUFFER)
			if (emptyCount < 0)
				if (~obj.IsFixedCapacity)
					frameCap = extendCapacity(obj, fillCount);
					emptyCount = frameCap - fillCount;					
				else
					% TODO: warn buffer overflow, or notify and save overflow with flag
					warning('Ignition:Core:Buffer:Write:BufferOverWrite',...
						'Unread frames overwritten in ring buffer')
					% PUSH READ IDX (DROP FRAMES)
					obj.LastReadIdx = mod(newLastIdx-1, frameCap) + 1;
					emptyCount = 0;
					fillCount = frameCap;
				end
			end
			
			% LOOP INDICES
			if (newLastIdx > frameCap)
				elementIdx = mod(elementIdx-1, frameCap) + 1;
			end
			
			% FILL SPECIFIED BUFFER ELEMENTS WITH DATA
			setData(obj.Block(1:numChannelsIn, elementIdx), data);
			
			% UPDATE INTERNAL COUNT & REFERENCES TO FIRST & LAST NODES
			obj.LastWriteIdx = elementIdx(end);
			obj.FramesAvailableCount = fillCount;
			obj.SpaceAvailableCount = emptyCount;
			
			% NOTIFY IF BUFFER IS FULL
			
			% NOTIFY NEW FRAMES AVAILABLE
			
			% NOTIFY IF SPACE IS AVAILABLE
			% todo
			
		end
		function data = read(obj, numFrames, channelIdx)
			
			% DEFAULT READ REQUEST (NO ARGS) RETURNS 1 ELEMENT
			if nargin < 3
				channelIdx = 1:obj.ChannelCapacity;
				if nargin < 2
					numFrames = 1;
				end
			end
			
			% LIMIT TO FRAMES AVAILABLE (RETURN IF 0)
			fillCount = obj.FramesAvailableCount;
			numFrames = min(numFrames, fillCount);
			if numFrames < 1
				data = [];
				return
			end
			
			% GET INDEX INTO INTERNAL BUFFER-ELEMENT-ARRAY
			lastIdx = obj.LastReadIdx;
			newLastIdx = lastIdx + numFrames;
			elementIdx = (lastIdx+1):newLastIdx;
			currentCapacity = size(obj.Block,2);
			if (newLastIdx > currentCapacity)
				elementIdx = mod(elementIdx-1, currentCapacity) + 1;
			end
			
			% READ DATA FROM NEXT BUFFER ELEMENTS (BLOCKS)
			data = getData(obj.Block(channelIdx,elementIdx));
			
			% UPDATE FULL/EMPTY BUFFER COUNTS
			fillCount = fillCount - numFrames;
			emptyCount = currentCapacity - fillCount;
			obj.LastReadIdx = newLastIdx;
			obj.FramesAvailableCount = fillCount;
			obj.SpaceAvailableCount = emptyCount; %obj.FrameCapacity + fillCount;
			
		end
	end
	methods (Hidden)
		function frameCap = extendCapacity(obj, fillCount)
			
			if nargin < 2
				fillCount = size(obj.Block,2) + obj.VariableCapacityIncrement;
			end
			% 			currentCapacity = size(obj.Block,2);
			[channelCap , frameCap] = size(obj.Block);
			emptyCount = frameCap - fillCount;
			lastWriteIdx = obj.LastWriteIdx;
			
			% EXTEND CAPACITY
			extensionCount = 0;
			extensionIncrement = obj.VariableCapacityIncrement;
			while (emptyCount < 0)
				frameCap = frameCap + extensionIncrement;
				extensionCount = extensionCount + extensionIncrement;
				emptyCount = frameCap - fillCount;
			end
			if (lastWriteIdx > obj.LastReadIdx)
				% POST EXTEND
				obj.Block(channelCap,frameCap) = ignition.core.BufferElement();
			else
				% INSERT EXTENSION
				extensionInsertElements = repelem(ignition.core.BufferElement(), channelCap, extensionCount);
				obj.Block = [obj.Block(:, 1:lastWriteIdx) , extensionInsertElements , obj.Block(:, (lastWriteIdx+1):end)];
				obj.LastReadIdx = obj.LastReadIdx + extensionCount;
			end
			obj.FrameCapacity = max(obj.FrameCapacity, frameCap);
			
		end
	end
	
	% CALLBACKS (TODO) OR EVENTS
	
	
end













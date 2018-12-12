classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		FrameBuffer < handle %& matlab.mixin.Heterogeneous
	% todo -> rename FrameBuffer? also implement RingBuffer?
	% bufItem = parallel.internal.cluster.ByteBufferItemWrapper.wrapInByteBufferItem(element)
	
	properties
		FrameCapacity = 32
	end
	properties (SetAccess = protected)
		LastWriteIdx = 0
		LastReadIdx = 0 % todo implement relative to FrameCapacity?
		FramesAvailableCount = 0
		SpaceAvailableCount
		FramesPerUnitCount % FilledUnitFrameCount
	end
	properties (SetAccess = protected)		
		ElementBlock @ign.core.FrameBufferElement vector
		ElementFrameCount
		MaxNumFramesPerUnit
		% or BufferUnitBlock -> StreamPacket
	end
	properties (Constant, Hidden)
		VariableCapacityIncrement = 32
	end
	properties (SetAccess = immutable)
		IsFixedCapacity @logical scalar = false
	end
	
	
	
	% INITIALIZATION
	methods
		function obj = FrameBuffer(frameCapacity, useFixed)
			% Use capacity argument to either specify an initial size, or a max size
			%
			%		Fixed FrameCapacity:
			%				>> obj = ign.core.FrameBuffer(32, true)
			%				>> obj = ign.core.FrameBuffer(inf)
			%
			%		Variable FrameCapacity:
			%				>> obj = ign.core.FrameBuffer(32, false)
			%				>> obj = ign.core.FrameBuffer(32)
			%				>> obj = ign.core.FrameBuffer()
			%
			
			initialFrameCapacity = obj.VariableCapacityIncrement;
			
			if nargin
				if (nargin > 1)
					try obj.IsFixedCapacity = useFixed; catch me, disp(me.message), end
				end				
					if isinf(frameCapacity)
						obj.IsFixedCapacity = false;
					else
						initialFrameCapacity = frameCapacity;
					end
					obj.FrameCapacity = frameCapacity;			
			end
			
			obj.ElementBlock(1, initialFrameCapacity) = ign.core.FrameBufferElement();
			obj.SpaceAvailableCount = initialFrameCapacity;			
			
		end
		% todo -> Construct read-only shadow (InputBuffer)
		% todo -> Construct read-only extended shadow with background devicemem-sysmem transfer
	end
	
	% GENERAL USE
	methods
		function write(obj, data)
			
			% GET CURRENT & REQUIRED ARRAY-SIZE			
			frameCap = size(obj.ElementBlock, 2);
			
			% NUMERIC ARRAY INPUT			
			% [numDataChannels, numDataFrames] = ign.shared.getNumChannelsAndFrames(data);
			% todo: check if numel(obj) == numDataChannels && numel(obj)>1
			numDataFrames = ign.shared.getNumFrames(data);
			fillCount = obj.FramesAvailableCount + numDataFrames;
			emptyCount = frameCap - fillCount;
			lastIdx = obj.LastWriteIdx;
			newLastIdx = lastIdx + numDataFrames;
			
			% GET INDEX INTO INTERNAL BUFFER-ELEMENT-ARRAY
			elementIdx = (lastIdx+1):newLastIdx;
			
			% EXTEND BUFFER (VARIABLE SIZE) OR LOOP INDICES (RING BUFFER)
			if (emptyCount < 0)
				if (~obj.IsFixedCapacity)
					frameCap = extendCapacity(obj, fillCount);
					emptyCount = frameCap - fillCount;					
				else
					% TODO: warn buffer overflow, or notify and save overflow with flag
					warning('Ign:Core:FrameBuffer:Write:FrameBufferOverWrite',...
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
			setData(obj.ElementBlock(elementIdx), data);
			% obj.ElementFrameCount(elementIdx) = %todo
			
			% UPDATE INTERNAL COUNT & REFERENCES TO FIRST & LAST NODES
			obj.LastWriteIdx = elementIdx(end);
			obj.FramesAvailableCount = fillCount;
			obj.SpaceAvailableCount = emptyCount;
			
			% NOTIFY IF BUFFER IS FULL
			
			% NOTIFY NEW FRAMES AVAILABLE
			
			% NOTIFY IF SPACE IS AVAILABLE
			% todo
			
		end
		function [data, numFrames] = read(obj, numFrames)
			
			% DEFAULT READ REQUEST (NO ARGS) RETURNS 1 ELEMENT
			if nargin < 2
				numFrames = 1;
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
			currentCapacity = size(obj.ElementBlock,2);
			if (newLastIdx > currentCapacity)
				elementIdx = mod(elementIdx-1, currentCapacity) + 1;
			end
			
			% READ DATA FROM NEXT BUFFER ELEMENTS (BLOCKS)
			data = getData(obj.ElementBlock(elementIdx));
			
			% UPDATE FULL/EMPTY BUFFER COUNTS
			fillCount = fillCount - numFrames;
			emptyCount = currentCapacity - fillCount;
			obj.LastReadIdx = newLastIdx;
			obj.FramesAvailableCount = fillCount;
			obj.SpaceAvailableCount = emptyCount; %obj.FrameCapacity + fillCount;
			
		end
		function data = peek(obj, numFrames)
			
			% DEFAULT PEEK REQUEST (NO ARGS) RETURNS 1ST ELEMENT
			if nargin < 2
				numFrames = 1;
			end
			
			% GET LOCAL VARIABLES FROM PROPS
			frameCap = obj.FrameCapacity;
			lastReadIdx = obj.LastReadIdx;
			lastWriteIdx = obj.LastWriteIdx;
			bufferBlock = obj.ElementBlock;
			hasFrame = ~isEmpty(bufferBlock);
			
			% RETURN IF ALL BUFFERS ARE EMPTY
			if ~any(hasFrame)
				data = [];
				return
			end
			
			% LIMIT TO UNIQUE FRAMES
			numFrames = min( numFrames, sum(hasFrame));
			
			% GET INDEX TO NON-EMPTY BUFFERS MOST RECENTLY WRITTEN TO
			idx = 1:frameCap;
			idx = idx(hasFrame);
			idx = circshift(idx, numFrames - lastWriteIdx);
			idx = idx(1:numFrames);
			
			% READ DATA SELECTED BUFFERS (RESTORING THE READ/UNREAD STATE)
			peekBufferBlock = bufferBlock(idx);
			prePeekReadState = {peekBufferBlock.IsUnread};
			data = getData(peekBufferBlock);
			[peekBufferBlock.IsUnread] = prePeekReadState{:};
			
		end
		function count = getSpaceAvailable(obj)
			count = [obj.SpaceAvailableCount];
		end
		function count = getDataAvailable(obj)
			count = [obj.FramesAvailableCount];
		end
	end
	methods (Hidden)
		function frameCap = extendCapacity(obj, fillCount)
			
			if nargin < 2
				fillCount = size(obj.ElementBlock,2) + obj.VariableCapacityIncrement;
			end
			frameCap = size(obj.ElementBlock, 2);
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
				obj.ElementBlock(1,frameCap) = ign.core.FrameBufferElement();
			else
				% INSERT EXTENSION
				extensionInsertElements = repelem(ign.core.FrameBufferElement(), 1, extensionCount);
				obj.ElementBlock = [obj.ElementBlock(1:lastWriteIdx) , extensionInsertElements , obj.ElementBlock((lastWriteIdx+1):end)];
				obj.LastReadIdx = obj.LastReadIdx + extensionCount;
			end
			obj.FrameCapacity = max(obj.FrameCapacity, frameCap);
			
		end
	end
	
	% CALLBACKS (TODO) OR EVENTS
	
	
	
	
	methods (Static)
		function obj = buildRingBuffer(capacity)
			if nargin<1
				capacity = 64;
			end
			obj = ign.core.FrameBuffer( capacity, true);
			
		end
		function obj = buildExpandableBuffer( initialCapacity )
			if nargin<1
				initialCapacity = 64;
			end
			obj = ign.core.FrameBuffer( initialCapacity, false);
			
		end
	end
	
end













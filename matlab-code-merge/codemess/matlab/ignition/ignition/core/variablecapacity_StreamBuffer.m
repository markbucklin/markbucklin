classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		Buffer < handle %& matlab.mixin.Heterogeneous
	
	
	
	properties
		FixedCapacity @logical scalar = true
	end
	properties (SetAccess = protected)
		LastWriteIdx = 0
		LastReadIdx = 0
		FramesAvailableCount = 0
		SpaceAvailableCount = 1
		Capacity = 1
	end
	properties (Access = protected)
		Block @ignition.core.BufferElement vector
	end
	
	
	
	
	% INITIALIZATION
	methods
		function obj = Buffer(capacity)
			
			if nargin
				if isinf(capacity)
					obj.FixedCapacity = false;
					obj.Block(32) = ignition.core.BufferElement();
				else
					obj.Block(capacity) = ignition.core.BufferElement();
				end
				obj.Capacity = capacity;
				obj.SpaceAvailableCount = capacity;
				
			end
			
		end
	end
	
	% GENERAL USE
	methods
		function write(obj, data)
			
			% GET CURRENT & REQUIRED ARRAY-SIZE			
			currentCapacity = numel(obj.Block); %obj.Capacity;
			
			
			% NUMERIC ARRAY INPUT
			if isnumeric(data)
				numDataElements = size(data,4);
			else
				numDataElements = size(data,2);
			end
			fillCount = obj.FramesAvailableCount + numDataElements;
			lastIdx = obj.LastWriteIdx;
			newLastIdx = lastIdx + numDataElements;
			
			% GET INDEX INTO INTERNAL BUFFER-ELEMENT-ARRAY
			elementIdx = (lastIdx+1):newLastIdx;
						
			if ~obj.FixedCapacity
				% EXPAND CAPACITY
				if (newLastIdx > currentCapacity)
					currentCapacity = newLastIdx;
					obj.Block(newLastIdx) = ignition.core.BufferElement();
				end				
			else
				% LOOP INDICES
				elementIdx = mod(elementIdx-1, currentCapacity) + 1;
			end
			
			% ASSIGN NODE CONTENTS
			setData(obj.Block(elementIdx), data);
			
			
			% UPDATE INTERNAL COUNT & REFERENCES TO FIRST & LAST NODES			
			obj.Capacity = max(obj.Capacity, currentCapacity);
			obj.LastWriteIdx = newLastIdx;
			obj.FramesAvailableCount = fillCount;
			obj.SpaceAvailableCount = obj.Capacity - fillCount;
			
		end
		function data = read(obj, numDataElements)
			if nargin < 2
				numDataElements = 1;
			end
			currentCount = obj.FramesAvailableCount;
			numDataElements = min(numDataElements, currentCount);
			
			if numDataElements < 1
				data = [];
				return
			end
			
			lastIdx = obj.LastReadIdx;
			newLastIdx = lastIdx + numDataElements;
			blockIdx = (lastIdx+1):newLastIdx;
			if (newLastIdx > obj.Capacity)
				blockIdx = mod(blockIdx-1, obj.Capacity) + 1;
			end
			
			data = getData(obj.Block(blockIdx));
			fillCount = currentCount - numDataElements;
			
			obj.LastReadIdx = newLastIdx;			
			obj.FramesAvailableCount = fillCount;
			obj.SpaceAvailableCount = obj.Capacity + fillCount;
		end
	end
	
	
	
	
	
	
	
end













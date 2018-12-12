classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		FrameBufferElement < handle ...
		& matlab.mixin.Heterogeneous
	%& ignition.core.type.DataContainerBase ...
	
	% todo -> ignition.core.UniquelyIdentifiable & ignition.core.Handle
	
	
	properties (SetAccess = {?ignition.core.FrameBuffer,?ignition.core.FrameBufferElement})
		Data
		IsUnread @logical scalar = false
		IsLocked @logical scalar = false % todo
		RequiresReadLock @logical scalar = false % todo
		ReadLockCount = 0; % todo
	end
	
	
	
	
	methods
		function obj = FrameBufferElement(data)
			
			if nargin
				
				% GET NUMBER OF NODES INTENDED TO BE CREATED & LINKED WITH THIS CONSTRUCTION
				numElements = numel(data);
				
				% PROCEED WITH MULTI- OR SINGLE-ELEMENT CONSTRUCTION
				if (numElements > 1) && ~isnumeric(data)
					% INITIALIZE EMPTY OBJECT ARRAY
					obj(numElements) = eval(class(obj));
					
				end
				
				% INITIALIZE DATA
				setData(obj, data);
				
			end
			
		end
		function setData(obj, data)
			
			try
				% GET NUMBER OF BUFFER ELEMENTS
				numBufferElements = size(obj,2);
				
				% GET NUMBER OF CHANNELS & FRAMES IN DATA
				numDataFrames = ignition.shared.getNumFrames(data);
				
				% TODO -> implement entirely in DataContainerBase
				if (iscell(data))
					% CELL INPUT
					[obj(1:numDataFrames).Data] = data{:};
					
				elseif (numDataFrames == 1)
					% SIMPLE ASSIGNMENT
					obj(1).Data = data;
					
				elseif isobject(data) || isstruct(data)
					% DATA-CONTAINER CLASS
					for k = 1:numBufferElements % todo
						obj(k).Data = data(k);
					end
					
				elseif isnumeric(data)
					% NUMERIC
					for k = 1:numBufferElements  % todo
						obj(k).Data = data(:,:,:,k);
					end
					
				end
			catch me %TODO
				disp(me.message)
			end
			
			% SET UNREAD STATE
			[obj.IsUnread] = deal(true);
			
		end
		function data = getData(obj, frameDim)
			
			% todo -> (maybe??) enable multi-channel data return (see DataContainerBase)
			
			% GET DIMENSION OF CONCATENTATION
			if nargin < 2
				firstData = obj(1).Data;
				if isnumeric(firstData)
					frameDim = 4;
				else
					frameDim = 2;
				end
			end
			
			% CONCATENATE TO NUMERIC ARRAY OR ARRAY OF DATA-CONTAINERS
			data = cat( frameDim , obj.Data);
			
			% RESET UNREAD STATE
			[obj.IsUnread] = deal(false);
			
		end
		function b = isEmpty(obj)
			b = true(size(obj));
			try
				elementIsValid = isvalid(obj);
				b(~elementIsValid) = true;
				if any(elementIsValid)
					b(elementIsValid) = cellfun( @isempty, {obj(elementIsValid).Data} );
				end
				
			catch
			end
		end
		function wipe(obj)
			
			% GET PROTOTYPIC DATA-TYPE FROM DATA PROP OF FIRST ELEMENT
			protoData = obj(1).Data;
			
			% GET EMPTY (NULL) VERSION OF PROTOTYPIC DATA
			if isnumeric(protoData)
				emptyData = cast([],'like',protoData);
			elseif isobject(protoData)
				emptyData = protoData.empty();
			elseif isstruct(protoData)
				emptyData = struct.empty();
			elseif iscell(protoData)
				emptyData = {};
			else
				emptyData = [];
			end
			
			% ASSIGN EMPTY DATA TO ALL BUFFER ELEMENTS IN ARRAY
			[obj.Data] = deal(emptyData);
			
			% RESET UNREAD STATE
			[obj.IsUnread] = deal(false);
			
		end
	end
	
	
	
	
	
end






























% 						try
% 							while hasNext(lastNode)
% 								lastNode = lastNode.Next;
% 							end
% 						catch
% 						end

% 			try
% 				currentNode = obj(1);
% 				allNextNodes = [obj.Next];
% 				nextNode = allNextNodes(1);
% 				while isvalid(currentNode)
% 					b = ~isempty(obj.Next.Value);
% 					b = b && isvalid(obj.Next);
% 					lastNode = lastNode.Next;
% 				end
% 			catch
% 			end

classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		LinkedList < handle & matlab.mixin.Heterogeneous
	
	
	
	properties (Transient, SetAccess = ?ignition.core.Object)
		First @ignition.core.LinkedListNode scalar
		Last @ignition.core.LinkedListNode scalar
		Count = 0
	end
	properties % Access = protected
		NodeArray @ignition.core.LinkedListNode vector
	end
	
	
	
	methods
		function obj = LinkedList(numNodes)
			
			if nargin
				obj.NodeArray(numNodes) = ignition.core.LinkedListNode();
			end
			
		end
		function add(obj, nodeContents)
			
			% GET CURRENT & REQUIRED ARRAY-SIZE
			currentCount = obj.Count;
			currentCapacity = numel(obj.NodeArray);
			numNewNodes = numel(nodeContents);
			newCount = currentCount + numNewNodes;
			
			% GET INDEX INTO INTERNAL NODE-ARRAY FOR ADDED ELEMENTS
			newIdx = currentCount + (1:numNewNodes);
			
			% EXPAND SIZE OF LINKED NODE ARRAY
			if (newCount > currentCapacity)
				obj.NodeArray(newCount) = ignition.core.LinkedListNode();
				k = max(1,currentCapacity);
				while (k < newCount)
					obj.NodeArray(k).Next = obj.NodeArray(k+1);
					k = k + 1;
				end
			end
			
			% ASSIGN NODE CONTENTS
			setNodeValue(obj.NodeArray(newIdx), nodeContents);
			% 			if iscell(nodeContents)
			% 				[obj.NodeArray(newIdx)] = nodeContents{:};
			% 			else
			% 				for k = newIdx
			% 					obj.NodeArray(k).Value = nodeContents(k);
			% 				end
			% 			end
			
			
			% 			obj.NodeArray(newIdx) = ignition.core.LinkedListNode(nodeContents, obj.Last);
			% UPDATE INTERNAL COUNT & REFERENCES TO FIRST & LAST NODES
			updateCount(obj, newCount);
			% 			obj.Count = newCount;
			% 			obj.First = obj.NodeArray(1);
			% 			obj.Last = obj.NodeArray(newCount);
			
		end
		function addFirst(obj, node)
			currentFirst = obj.First;
			node(end).Next = currentFirst;
			obj.NodeArray = [ node , obj.NodeArray];
			newCount = obj.Count + numel(node);
			updateCount(obj, newCount);
		end
		function addLast(obj, node)
			currentLast = obj.Last;
			if ~isempty(currentLast)
				currentLast.Next = node(1);
			end
			obj.NodeArray = [obj.NodeArray , node];
			newCount = obj.Count + numel(node);
			updateCount(obj, newCount);
		end
		function node = remove(obj, idx)
			if nargin < 2
				idx = 1;
			end
			try
				node = obj.NodeArray(idx);
				obj.NodeArray(idx) = [];
				obj.First = obj.NodeArray(1);
				obj.Last = obj.NodeArray(end);
			catch
				
			end
			
		end
		function node = removeFirst(obj, numNodes)
			if nargin < 2
				numNodes = 1;
			end
			node = obj.NodeArray(1:numNodes);
			if numNodes<obj.Count
				obj.First = obj.NodeArray(numNodes + 1);
				obj.NodeArray(1:numNodes) = [];
			end
			
		end
		function node = removeLast(obj, numNodes)
			if nargin < 2
				numNodes = 1;
			end
			currentCount = obj.Count;
			numNodes = min(numNodes, currentCount);
			nodeIdx = (currentCount-numNodes+1):currentCount;
			node = obj.NodeArray(nodeIdx);
			newCount = currentCount - numNodes;
			updateCount(obj, newCount)
		end
		function node = copyNode(obj, idx)
			
			%todo
			if obj.Count < 1
				node = ignition.core.LinkedListNode();
				return
			end
			if nargin < 2
				idx = 1:obj.Count;
			end
			try
				currentNodeArray = obj.NodeArray(idx);
				currentArrayFirst = getFirst(currentNodeArray);
				currentPreviousNode = currentArrayFirst.Previous;
				node = ignition.core.LinkedListNode([currentNodeArray.Value], currentPreviousNode);
			catch
				
			end
		end
		function firstNode = getFirst(obj)
			firstNode = obj.First;
		end
		function lastNode = getLast(obj)
			lastNode = obj.Last;
		end
	end
	
	methods (Access = protected)
		function updateCount(obj, newCount)
			obj.Count = newCount;
			obj.First = obj.NodeArray(1);
			obj.Last = obj.NodeArray(newCount);
		end
	end
	
	
	
	
	
	
	
end













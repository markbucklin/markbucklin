classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		DoublyLinkedListNode < handle & matlab.mixin.Heterogeneous
	
	
	
	properties (Transient, SetAccess = ?ignition.core.Object)
		Next @handle scalar
		Previous @handle scalar
		Value
	end
	
	
	
	
	methods
		function obj = DoublyLinkedListNode(nodeValue, previousLink)
			
			if nargin % && isa(nodeValue,'handle')
				
				% GET NUMBER OF NODES INTENDED TO BE CREATED & LINKED WITH THIS CONSTRUCTION
				numNodes = numel(nodeValue);
				
				if (numNodes <= 1)
					% SIMPLE ASSIGNMENT OF NODE-VALUE FOR SCALAR INPUT
					obj(1).Value = nodeValue;
					
				else
					% INITIALIZE EMPTY OBJECT ARRAY
					obj(numNodes) = eval(class(obj)); % getDefaultScalarElement
					
					% INITIALIZE CHAINING MECHANISM FOR LINKING LIST IN AN ARRAY
					k = 1;
					currentNode = obj(1);
					
					% INITIALIZE PREVIOUS NODE TO EMPTY NODE IF NOT PASSED AS 2ND ARG
					if (nargin < 2)
						previousNode = eval(class(obj));
						
					else
						% CONNECT WITH PREVIOUSLY FORMED LINKED-LIST NODES (as node or list)
						% 						if ~isa(previousNode, class(obj))
						previousNode = getLast(previousLink); % TODO: override in linkedlist class
						
					end
					previousNode.Next = currentNode;
					
					while (k < numNodes)
						% GET CURRENT & NEXT NODES
						currentNodeVal = nodeValue(k);
						currentNode = obj(k);
						nextNode = obj(k+1); % nodeValue(k+1);
						
						
						% ASSIGN NODES
						currentNode.Value = currentNodeVal; % todo: check if iscell?
						currentNode.Previous = previousNode;
						currentNode.Next = nextNode;
						
						% INCREMENT
						previousNode = currentNode;
						currentNode = nextNode;
						k = k + 1;
						
					end
					
					% SET LAST (OR ONLY) NODE DEFAULT PLACEHOLDER VALUES
					currentNode.Value = nodeValue(k);
					currentNode.Previous = previousNode;
					currentNode.Next = eval(class(obj));
					
				end
				
				% 				for k=1:numel(nodeValue)
				% 					obj(k).Value = nodeValue(k);
				% 				end
				
				
				
			end
			
		end
		function b = hasNext(obj)			
			b = false(size(obj));
			try
				if (numel(obj)==1)
					b = ~isempty(obj.Next.Value);
					b = b && isvalid(obj.Next);
				elseif (numel(obj)>1)
					nodeIsValid = isvalid(obj);
					nextNode = [obj(nodeIsValid).Next];
					nextNodeIsValid(nodeIsValid) = isvalid(nextNode);
					nextNodeIsNonEmpty = ~cellfun(@isempty, {nextNode(nextNodeIsValid(nodeIsValid)).Value});
					b(nextNodeIsValid(nodeIsValid)) = nextNodeIsNonEmpty;
					% 					nextNode = [obj.Next];
					% 					b = ~cellfun(@isempty, {nextNode.Value});
					% 					b = b & isvalid(nextNode);
				end
				
			catch
			end
		end
		function b = hasPrevious(obj)
			b = false(size(obj));
			try
				if (numel(obj)==1)
					b = ~isempty(obj.Previous.Value);
					b = b && isvalid(obj.Previous);%TODO:put before isempty?
				elseif (numel(obj)>1)
					nodeIsValid = isvalid(obj);
					previousNode = [obj(nodeIsValid).Previous];
					previousNodeIsValid(nodeIsValid) = isvalid(previousNode);
					previousNodeIsNonEmpty = ~cellfun(@isempty, {previousNode(previousNodeIsValid(nodeIsValid)).Value});
					b(previousNodeIsValid(nodeIsValid)) = previousNodeIsNonEmpty;
					% 					b = ~cellfun(@isempty, {prevNode.Value});
					% 					b = b & isvalid(prevNode);
				end
			catch
			end
		end
		function firstNode = getFirst(obj)
			nodeWithPrevious =  obj(hasPrevious(obj));
			firstNode = nodeWithPrevious(1);
			try
				while hasPrevious(firstNode)
					firstNode = firstNode.Previous;
				end
			catch
			end
		end
		function lastNode = getLast(obj)
			nodeWithNext = obj(getNext(obj));
			lastNode = nodeWithNext(end);
			try
				while hasNext(lastNode)
					lastNode = lastNode.Next;
				end
			catch
			end
		end
	end
	
	
	
	
	
end













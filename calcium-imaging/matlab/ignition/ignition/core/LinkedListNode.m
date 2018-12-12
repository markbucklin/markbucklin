classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		LinkedListNode < handle & matlab.mixin.Heterogeneous
	
	
	
	properties (Transient)
		Next @ignition.core.LinkedListNode scalar
		Value
	end
	
	
	
	
	methods
		function obj = LinkedListNode(nodeValue, varargin)
			
			if nargin
				
				% GET NUMBER OF NODES INTENDED TO BE CREATED & LINKED WITH THIS CONSTRUCTION
				numNodes = numel(nodeValue);
				isCellTypeInput = iscell(nodeValue);
				
				if (numNodes <= 1)
					% SIMPLE ASSIGNMENT OF NODE-VALUE FOR SCALAR INPUT
					if isCellTypeInput
						obj(1).Value = nodeValue{1};
					else
						obj(1).Value = nodeValue;
					end
					
				else
					% INITIALIZE EMPTY OBJECT ARRAY
					obj(numNodes) = eval(class(obj)); % getDefaultScalarElement
					
					% INITIALIZE CHAINING MECHANISM FOR LINKING LIST IN AN ARRAY
					k = 1;
					currentNode = obj(1);
					
					if (nargin > 1)
						previousNode = varargin{1};
						if ~isempty(previousNode)
							previousNode.Next = currentNode;
						end
					end
					
					while (k < numNodes)
						% GET CURRENT & NEXT NODES
						if isCellTypeInput
							currentNodeVal = nodeValue{k};
						else
							currentNodeVal = nodeValue(k);
						end
						
						currentNode = obj(k);
						nextNode = obj(k+1); % nodeValue(k+1);
						
						
						% ASSIGN NODES
						currentNode.Value = currentNodeVal; % todo: check if iscell?
						currentNode.Next = nextNode;
						
						% INCREMENT
						currentNode = nextNode;
						k = k + 1;
						
					end
					
					% SET LAST (OR ONLY) NODE DEFAULT PLACEHOLDER VALUES
					currentNode.Value = nodeValue(k);
					currentNode.Next = eval(class(obj));
					
				end
				
				
				
				
			end
			
		end
		function setNodeValue(obj, nodeValue)
			numNodes = numel(obj);
			numValues = numel(nodeValue);
			
			if (iscell(nodeValue))
				[obj.Value] = nodeValue{:};
			elseif (numValues < numNodes)
				[obj.Value] = deal(nodeValue);
				
			else
				for k = 1:numNodes
					obj(k).Value = nodeValue(k);
				end
			end
			
		end
		function b = hasNext(obj)
			b = false(size(obj));
			try
				% 				if (numel(obj)==1)
				% 					b = ~isempty(obj.Next.Value);
				% 					b = b && isvalid(obj.Next);
				% 				elseif (numel(obj)>1)
				nodeIsValid = isvalid(obj);
				if any(nodeIsValid)
					b(nodeIsValid) = ~cellfun( @isempty, {obj(nodeIsValid).Next} );
				end
				
				% 					nextNode = [obj(nodeIsValid).Next];
				% 					nextNodeIsValid = false(size(nextNode));
				% 					nextNodeIsValid(nodeIsValid) = isvalid(nextNode);
				% 					nextNodeIsNonEmpty = ~cellfun(@isempty, {nextNode(nextNodeIsValid(nodeIsValid)).Value});
				% 					b(nextNodeIsValid(nodeIsValid)) = nextNodeIsNonEmpty;
				
				% 				end
				
			catch
			end
		end
		function lastNode = getLast(obj)
			% 			lastNode = obj(end);
			
			nodeWithNext = obj(hasNext(obj));
			lastNode = nodeWithNext(end).Next;
			
			
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

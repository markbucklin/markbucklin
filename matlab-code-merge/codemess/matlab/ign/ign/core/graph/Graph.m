classdef (CaseInsensitiveProperties, TruncatedProperties)...
		Graph ...
		< ign.core.Handle ...		
		& ign.core.CustomDisplay ...
		& ign.core.Unique ...
		& ign.core.Hierarchical
	
	
	% GRAPH PROPERTIES
	properties (SetAccess = protected) %(Dependent)
		NodeCount = 0
		EdgeCount = 0
	end
	
	properties (SetAccess = protected)
		NodeList @ign.core.graph.Node
		EdgeList @ign.core.graph.Edge		
	end
	properties (Constant)
		DefaultDirected = true
	end
	
	
	
	% CONSTRUCTOR
	methods
		function obj = Graph( graphDef, varargin)
			
			% SUPERCLASS HANDLES PROP-VALUE ARGUMENTS TO INITIALIZE PROPERTIES
			obj = obj@ign.core.Handle(varargin{:});
						
			if nargin
				% 1ST ARG -> OPTIONAL GRAPH-DEFINITION 
				if ~isempty(graphDef)					
					switch class(graphDef)
						case 'ign.core.graph.Node'
							% ADJACENCY LIST
							obj.NodeList = graphDef;
							
						case 'ign.core.graph.Edge'
							% EDGE LIST
							obj.EdgeList = graphDef;
							
						case 'logical'
							% ADJACENCY MATRIX
							% todo: adjacency matrix
							% buildFromMatrix(obj, arg)
							
						case 'cell'
							% cell array of Node IDs
							
					end
					
				end
			end
			
		end
	end
	
	% BUILDING METHODS
	methods
		function [node, index] = addNode( graph, node, varargin)
									
			if nargin < 2
				node = [];
			end
			
			if ~isa(node, 'ign.core.graph.Node')
				% CONSTRUCT NODE OBJECT FROM NAME OR ID
				nodeDef = node;
				if iscell(nodeDef)
					node = cellfun(@(nd) constructSingleNode(nd, varargin), nodeDef);
				else
					node = constructSingleNode(nodeDef, varargin);
				end				
			end						
			
			% ADD NODE OBJECT TO LIST OF STORED NODE OBJECTS
			index = graph.NodeCount + (1:numel(node));
			graph.NodeList = [graph.NodeList , node(:)'];
			graph.NodeCount = graph.NodeCount + numel(node);
			[node.Graph] = deal(graph);
						
			% NODE CONSTRUCTION FUNCTION
			function nodeObj = constructSingleNode( nodeDef, attrArgs)
				if ischar(nodeDef)
					% NODE NAME
					nodeObj = ign.core.graph.Node( [], nodeDef, attrArgs{:});					
				elseif isnumeric(nodeDef)
					% NODE ID
					nodeObj = ign.core.graph.Node( nodeDef, [], attrArgs{:});					
				else
					nodeObj = ign.core.graph.Node( [], [], attrArgs{:});
					%error('Graph:addNode:invalidInput','Node specified as %s',class(node))
				end
			end
			
		end		
		function edge = addEdge( graph, source, target, directed, label)
			
			if nargin < 5
				label = [];
			end
			if (nargin < 4) || isempty(directed)
				directed = ign.core.graph.Graph.DefaultDirected;
			end			
			
			[source, sourceIndex] = getOrAddNode( graph, source);
			[target, targetIndex] = getOrAddNode( graph, target);
			
			edge = ign.core.graph.Edge( source, target, directed, label);
			
			source.Out = [source.Out, edge];
			target.In = [target.In, edge];
			
			graph.EdgeList = [graph.EdgeList, edge];
			graph.EdgeCount = graph.EdgeCount + numel(edge);
			
			
		end
		function success = removeNode( graph, node)
			try
				% GET INDEX OF SPECIFIED NODE
				if isa(node, 'ign.core.graph.Node')
					% NODE OBJECT
					rmIndex = [node.Index];
					
				elseif isnumeric(node)
					% NODE INDEX
					rmIndex = node;
					
				elseif ischar(node)
					% NODE NAME
					allIdx = [graph.NodeList.Index];
					rmIndex = allIdx(strcmp( node, {graph.NodeList.Name}));
					
				else
					% UNKNOWN
					success = false;
					return
					
				end
				
				
				rmIndex = rmIndex( graph.NodeList(rmIndex) == node);
				if ~isempty(rmIndex)
					graph.NodeList( rmIndex) = [];
				end
				success = true;
			catch
				success = false;
			end
		end
		function success = removeEdge( graph, edge)
			
		end
		function [node, index] = getNode( graph, nodeDef)
			
			nodeList = graph.NodeList;
			if iscell(nodeDef)
				[cnode, cindex] = cellfun(@(def) getSingleNode(def), nodeDef, 'UniformOutput', false);
				node = [cnode{:}];
				index = [cindex{:}];				
			else
				[node, index] = getSingleNode( nodeDef);				
			end
				
			function [el,idx] = getSingleNode(def)
				if isa( def, 'ign.core.graph.Element')
					[el,idx] = findElement( nodeList, def);
				elseif isnumeric(def)
					[el,idx] = findElement( nodeList, 'ID', def);
				elseif ischar(def)
					[el,idx] = findElement( nodeList, 'Name', def);
				else
					idx = [];
					el = nodeList(idx);
				end
			end
			
		end
		function [node, index] = getOrAddNode( graph, nodeDef)
			[node, index] = getNode( graph, nodeDef);
			if isempty(node)
				[node, index] = addNode( graph, nodeDef);
				%index = numel(obj.NodeList);				
			end
		end
		function graph = makeLink( graph, sourceNode, targetNode)
		end
	end
	
	% GRAPH TRANSFORMATION: PARTITIONING & EXPORT
	methods
		function subgraph = createSubGraph( obj, selector)
			
		end
	end
	
	% OVERLOADED OPERATOR (COMPARISON)
	methods
		function bool = eq(A,B)
			bool = eq@ign.core.Unique(A,B);
		end		
	end

	
end








	
% 	methods
% 		function n = get.NodeCount(obj)			
% 			n = numel(obj.NodeList);
% 		end
% 		function n = get.EdgeCount(obj)			
% 			n = numel(obj.EdgeList);
% 		end
% 	end
	
% 
% 			sourceIndex = find(source == nodeID, 1, 'first')
% 			targetIndex = find(target == nodeID, 1, 'first');
% 			
% 			if ~isempty(sourceIndex)
% 				sourceNode = nodeList(sourceIndex);
% 			else
% 				sourceNode = obj.addNode(source);
% 			end

	
	% 	InputEdgeIndex
	% 		OutputEdgeIndex
	
	

	% todo: maintain maps from UID->name, name->UID, UID->label, label->UID??
	%				... only if not handle, otherwise can just use, eq and findobj
	


% SUBFUNCTION IMPLEMENTING WHAT IS AN ACCEPTABLE 'NAME' QUERY {'','all',strmatch}
function match = searchByPropVal( q, V)
if ischar(q) && iscellstr(V)
	match = searchByName( q, V);
else
	try
		match = cellfun(@isequal, repmat(q,size(V)), V);
	catch
		match = false(size(V));
	end
end
% todo -> dig up the function for comparing struct fields and/or cells???
end

function match = searchByName( str, C)
if isempty(str)
	% EMPTY STR RETURNS EMPTY LIST (OR GRAPHS WITH EMPTY NAME)
	match = ~cellfun(@isempty, C);
	
elseif strcmpi(str,'all')
	% 'ALL' RETURNS ENTIRE LIST
	match = true(size(C));
else
	
	% MATCH GIVEN NAME EXACTLY
	match = strcmp( str, C);
	
	% ACCEPT CASE-INSENSITIVE & TRUNCATED MATCHES IF EXACT MATCH FAILES
	if ~any(match)
		match = strncmpi( str, C, length(str));
	end
end
end








%Name = 'DefaultGraph'
% 	AdjacencyMatrix
% 		IncidenceMatrix
% GraphBase PID, Device?

% pg = physmod.gl.Graph
% osgmod = matlab.graphics.primitive.world.osg.ModelFile



% 				for k=1:numel(obj)
% 				%obj(k).NodeList = [obj(k).NodeList(:) ; node(:)];
% 				obj(k).NodeList(end+1 : end+m) = node;
% 			end


% 
% 	methods
% 		function idx = nextNodeIndex(obj)
% 			if isempty(obj.NodeList)
% 				idx = 1;
% 			else
% 				maxNodeIndex = max([obj.NodeList.Index]);
% 				idx = maxNodeIndex + 1;
% 			end
% 		end		
% 		function idx = nextEdgeIndex(obj)
% 			if isempty(obj.EdgeList)
% 				idx = 1;
% 			else
% 				maxEdgeIndex = max([obj.EdgeList.Index]);
% 				idx = maxEdgeIndex + 1;
% 			end
% 		end
% 	end
% 
% node = ign.core.graph.Node.empty;
% for k = 1:numel(nodeName)
% 	node(k) = ign.core.graph.Node(nodeName{k}, varargin{:});
% end
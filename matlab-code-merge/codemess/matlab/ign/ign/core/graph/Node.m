classdef (CaseInsensitiveProperties, TruncatedProperties)...
		Node ...
		< ign.core.graph.Element ...
		& ign.core.Handle
	
	
	
	% NODE PROPERTIES
	properties
		Name
	end
	properties (SetAccess = {?ign.core.graph.Element, ?ign.core.graph.Graph}, Transient)		
		In @ign.core.graph.Edge
		Out @ign.core.graph.Edge
	end
	
	properties (SetAccess = {?ign.core.graph.Graph}, Transient)
		Graph
	end
	
	
	
	methods
		function obj = Node(id, name, varargin)
			
			obj = obj@ign.core.graph.Element([],varargin{:});
			
			if (nargin < 1) || isempty(name)
				name = sprintf('%s%d',ign.util.getClassName(obj), obj.ID);
			end
			
			if isempty(obj.Name)
				obj.Name = name;
			end
			
		end
		function obj = addToGraph( obj, graph)
			obj = addNode( graph, obj);
		end
		function edges = connect( source, targetList, directed)
			
			if nargin < 3
				directed = [];
			end
			graph = source.Graph;
			if isempty(graph)
				graph = ign.core.graph.Graph();
				source = addNode( graph, source);
			end
			
			k = numel(targetList);
			while (k >= 1)
				target = targetList(k);
				targetGraph = target.Graph;
				if isempty(targetGraph) || (targetGraph == graph)
					% ADD EDGE TO COMMON GRAPH
					edge = addEdge( graph, source, target, directed);
					
				else
					% MAKE VIRTUAL SOURCE/TARGET TO ADD TO SEPARATE GRAPHS
					commonGraph = getCommonGraph( graph, targetGraph);
					
				end
				edges(k) = edge;
				k = k - 1;
			end
			
			function g = getCommonGraph( g1, g2)
				[branch, common, ind1, ind2] = getCommonBranch(g1, g2);
				if isempty(branch)
					h1 = [getAncestors(g1); g1];
					h2 = [getAncestors(g2); g2];
					g = ign.core.graph.Graph();
					addChild(g, h1(1));
					addChild(g, h2(1));
				else
					
				end
			end
			
		end
	end
	
	
	
	
	
end






% ( Vertex )

%properties (SetAccess = {?ign.core.graph.Element})

% todo: remove graph
% add Label

% todo: change to a graphReference (i.e. graph.ID) and provide graph from static method

% Input @ign.core.graph.Edge
% Output @ign.core.graph.Edge

% todo -> function getEdges(obj, type) >> getEdges(obj,'Input') or Inbound or receiving

% todo: getLabel & getData, getLabel would be used if encapsulated data is stored in structure,
% where the 'label'=fieldName(data)

% new idea: use SetObservable to indicate all neighbor types (i.e. Input or Output or Control) and
% make type=Node. register listeners in each graph that creates a new Edge whenever a node
% connection is modified. the new Edge stores a reference to each node, as well as the relation
% type (i.e. 'Output') and the index into the relation-list. e.g. Edge =
% {{'<sourcenodeid>','Output',1} , {'<targetnodeid>','Input',1}} or the edge has 'Source' and
% 'Target' properties, where each is a structure with fields: { ID, Type/RelationType, Index }
%
% implement serializer 'Descriptor' classes...

% 
% function obj = Node( name, graph)
% 			
% 			% DEFAULT INPUT
% 			if nargin < 2
% 				graph = ign.core.graph.Graph.empty;
% 				graphName = 'null';
% 				nodeIndex = 0;
% 			else
% 				graphName = graph.Name;
% 				nodeIndex = nextNodeIndex(graph);
% 			end
% 			if nargin < 1
% 				name = sprintf('%s:node%d', graphName, nodeIndex);
% 			end
% 			
% 			% CALL ELEMENT CONSTRUCTOR WITH NAME
% 			obj = obj@ign.core.graph.Element( name);
% 			
% 			% SET GRAPH
% 			obj.Graph = graph;
% 			
% 			% SET IDX
% 			obj.Index = nodeIndex;
% 			
% 		end
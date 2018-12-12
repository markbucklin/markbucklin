classdef (CaseInsensitiveProperties, TruncatedProperties, HandleCompatible)...
		Edge ...
		< ign.core.graph.Element
	
	
	
	% EDGE PROPERTIES
	properties
		Label
	end
	properties (SetAccess = {?ign.core.graph.Element}, Transient)
		Source
		Target
	end
	properties (SetAccess = {?ign.core.graph.Element})
		IsDirected
	end
	
	% Graph @ign.core.graph.Graph
	
	
	
	methods
		function obj = Edge(source, target, directed, label, varargin)
			
			obj = obj@ign.core.graph.Element([],varargin{:});
			
			if (nargin < 3) || isempty(directed)
				directed = true;
			end
			if (nargin < 4) || isempty(label)
				if directed
					label = sprintf('%s>%s', source.Name, target.Name);
				else
					label = sprintf('%s<>%s', source.Name, target.Name);
				end
			end
			
			obj.Source = source;
			obj.Target = target;
			obj.Label = label;
			obj.IsDirected = directed;
			
		end

	end
	
	
end



% 		function obj = Edge(source, target, name, graph)
% 			
% 			% >> edge = ign.core.graph.Edge( {node,'output',1} )
% 			
% 			% DEFINE SOURCE
% 			if isa(source, 'ign.core.graph.Node')
% 				sourceNode = source;
% 				sourcePort = '';
% 				sourcePortIndex = [];
% 				
% 			elseif iscell(source)
% 				sourceNode = source{1};
% 				sourcePort = source{2};
% 				if numel(source) > 2
% 					sourcePortIndex = source{3};
% 				end
% 			end
% 			
% 			% DEFINE TARGET
% 			if isa(target, 'ign.core.graph.Node')
% 				targetNode = target;
% 				targetPort = '';
% 				targetPortIndex = [];
% 				
% 			elseif iscell(target)
% 				targetNode = target{1};
% 				targetPort = target{2};
% 				if numel(target) > 2
% 					targetPortIndex = target{3};
% 				end
% 			end
% 			
% 			% DEFAULT GRAPH SAME AS SOURCE GRAPH
% 			if nargin < 4
% 				%graph = sourceNode.Graph;
% 				graph = ign.core.graph.Graph.empty;
% 				graphName = 'base';
% 				edgeIndex = [];
% 			else
% 				graphName = graph.Name;
% 				edgeIndex = nextEdgeIndex(graph);
% 			end			
% 			
% 			
% 			% DEFAULT NAME CONSTRUCTED FROM SOURCE, TARGET, & GRAPH NAMES						
% 			if nargin < 3
% 				name = sprintf('%s:edge%d [%s:%s%d > %s:%s%d]',...
% 					graphName, edgeIndex,...
% 					sourceNode.Name, sourcePort, sourcePortIndex,...
% 					targetNode.Name, targetPort, targetPortIndex);
% 			end
% 			
% 			% CALL ELEMENT CONSTRUCTOR WITH NAME
% 			obj = obj@ign.core.graph.Element( name);
% 			
% 			% SET GRAPH
% 			obj.Graph = graph;
% 			
% 			% SET IDX
% 			obj.Index = edgeIndex;
% 			
% 			% SET SOURCE SPECIFICATION
% 			obj.Source.Node = sourceNode;
% 			obj.Source.Port = sourcePort;
% 			obj.Source.Index = sourcePortIndex;
% 			
% 			% SET TARGET SPECIFICATION
% 			obj.Target.Node = targetNode;
% 			obj.Target.Port = targetPort;
% 			obj.Target.Index = targetPortIndex;
% 		
% 			
% 		end
		% 		function obj = setTarget( obj, target)
		%
		% 			% GET CURRENT TARGET
		% 			currentTargetNode = obj.Target.Node;
		%
		% 			% REMOVE EDGE FROM CURRENT TARGET IF NONEMPTY
		% 			if ~isempty(currentTargetNode) && (currentTargetNode.Graph ~= obj.Graph)
		% 				removeEdge(currentTargetNode.Graph, obj);
		% 			end
		%
		% 			% ASSIGN TARGET NODE
		% 			obj.Target = target;
		%
		% 			% ADD/REPLACE EDGE IN SOURCE & CONTROL GRAPHS
		%
		%
		%
		% 		end
% 	end
% 	
% end




% Source = struct('Node',ign.core.graph.Node.empty,'Port','','Index',[])
% Target = struct('Node',ign.core.graph.Node.empty,'Port','','Index',[])

% todo make name & label from source

% change Source and Target to structures
% {{'<sourcenodeid>','Output',1} , {'<targetnodeid>','Input',1}} or the edge has 'Source' and
% 'Target' properties, where each is a structure with fields: { ID, Type/RelationType, Index
% 	IndexInSource
% 	IndexInTarget


% 	methods
% 		function set.Source(obj, source)
% 			assert(isa('ign.core.gf.Node',source))
% 			if ~isempty(obj.Parent) && (source.Parent ~= obj.Parent)
% 				removeNode( obj.Parent, obj)
% 			end
% 			obj.Parent = source.Parent;
% 			addNode( obj.Parent, obj)
% 		end
% 	end

% todo: method to create transfer/flow-control nodes in a bipartite graph


% (Neo4j -> Relationship)
% (			-> Link)



% 				obj.Parent = source.Parent;
% 				addEdge( obj.Parent, obj);

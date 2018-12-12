classdef (CaseInsensitiveProperties, TruncatedProperties, HandleCompatible)...
		EncapsulatedNode ...
		< ign.core.graph.Node ...
		& ign.core.Hierarchical
	

	properties (SetAccess = protected)
		ReferredNode
	end
	
	
	methods
		function obj = EncapsulatedNode(node, graph)
			
			% CALL SUPERCLASS CONSTRUCTOR TO COPY PROPERTIES
			id = node.ID;
			name = node.Name;
			args = {}; %todo
			obj = obj@ign.core.graph.Node( id, name, args{:});
			
			% ASSIGN REFERENCE TO SIMPLE NODE 
			obj.ReferredNode = node;
			
			% ADD TO PARENT GRAPH
			obj = addToGraph( graph, obj);
			
		end
	end

	
	
	
	
end



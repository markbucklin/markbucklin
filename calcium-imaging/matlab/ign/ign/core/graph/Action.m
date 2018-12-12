classdef Action ...
		< ign.core.graph.Node
	% Action  Nodes for producing, consuming, transforming, & transferring data in a DataflowGraph model
	
	% Analagous to "Transition" nodes in a Petri net model (i.e. events that may occur, represented by bars)
	% FlowOperator, FlowActor?? -> transform, consume, produce, transfer
	
	properties
		Function
		Description
		Enabled
	end
	

	
	
	methods
		function obj = Action(fcn, varargin)
			obj@ign.core.graph.Node(varargin{:});
			if nargin
				obj.Function = fcn;			
			end
		end
	end
	
	
	
	
end

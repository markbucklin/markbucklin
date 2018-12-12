classdef FlowControl ...
		< ign.core.graph.Node		
	% FlowControl  Nodes for controlling, aligning, synchronizing, & selecting data in a DataflowGraph model
	
	% Analagous to "Place" nodes in a Petri net model (i.e. conditions, represented by circles)
	
	
	properties
		Function
	end
	

	
	
	methods
		function obj = FlowControl(fcn, varargin)
			obj@ign.core.graph.Node(varargin{:});
			if nargin
				obj.Function = fcn;			
			end
		end
	end
	
	
	
	
end

classdef NumArgs
	
	properties
		In
		Out
	end
	
	
	methods
		function obj = NumArgs(in,out)
			obj.In = in;
			obj.Out = out;
		end
	end
	
end

% buildNumArgs = @(fcn) NumArgs(nargin(fcn),nargout(fcn))
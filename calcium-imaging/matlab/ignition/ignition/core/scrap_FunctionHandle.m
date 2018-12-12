classdef (Sealed) FunctionHandle < ignition.core.Object & handle & matlab.mixin.Copyable
	% FUNCTIONHANDLE
	
	
	
	
	properties (SetAccess=immutable)
		FunctionString = ''
		NumInputs @struct
		NumOutputs @struct
		
		
		IsVariableInput @logical
		IsVariableOutput @logical
	end
	properties (SetAccess=immutable, Hidden)
		MatlabFunctionHandle
	end
	
	
	methods
		function obj = FunctionHandle( fcn, varargin )
			
			if nargin
				obj.MatlabFunctionHandle = fcn;
				
				if nargin>1
					obj = parseConstructorInput(obj,varargin{:});
					
				end
			end
			
			if isempty(obj.NumInputArguments)
				obj.NumInputArguments = struct('min',inf,'max',-1,'last',nan);
				obj.IsVariableInput = true;
			end
			if isempty(obj.NumOutputArguments)
				obj.NumOutputArguments = struct('min',inf,'max',-1,'last',nan);
				obj.IsVariableOutput = true;
			end
			
		end
		
		function varargout = feval(obj, varargin)
			
			
			% 				numIn = nargin - 1; %numel(varargin)
			
			% 			numOut = nargout;
			
			try
				if nargout
					[varargout{1:max(1, nargout)}] = feval(obj.MatlabFunctionHandle, varargin{:});
				else
					feval(obj.MatlabFunctionHandle, varargin{:});
				end
			catch err
				throwAsFunction(obj, err);
			end
			
			% 			if obj.IsVariableOutput
			%
			% 			end
			% 			if obj.IsVariableOutput
			%
			% 		end
			
			
		end
		
		
		
	end
	
	
	
	
	
	
	
	
	
	
	
	
	
	
end
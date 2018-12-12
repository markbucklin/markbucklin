classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		Operation ...
		< ignition.core.FunctionHandle ...
		& ignition.core.CustomDisplay ...
		& matlab.mixin.Heterogeneous
	
	
	
	
	
	% OPERATION PROPERTIES
	properties (SetAccess = protected) % immutable) %
		NumInputArguments = 0
		NumOutputArguments = 0
	end
	
	properties (SetAccess = protected, Hidden) % immutable) %
		IsVariableInput = false
		IsVariableOutput = false
	end
	
	
	methods
		function obj = Operation(fcn, numInputs, numOutputs)
			
			obj = obj@ignition.core.FunctionHandle(fcn);
			
			% ASSIGN INPUT IF PROVIDED (OR DEFAULT)
			if nargin
				
				% DETERIMINE/SET NUM-OUTPUT-ARGUMENTS
				if nargin > 2
					assert(ignition.util.isWholeScalar(numOutputs));
				else
					numOutputs = nargout(obj.Function);
					if numOutputs<0
						obj.IsVariableOutput = true;
						numOutputs = abs(numOutputs);
					end
				end
				obj.NumOutputArguments = numOutputs;
				
				% DETERIMINE/SET NUM-INPUT-ARGUMENTS
				if nargin > 1
					assert(ignition.util.isWholeScalar(numInputs));
				else
					numInputs = nargin(obj.Function);
					if numInputs<0
						obj.IsVariableInput = true;
						numInputs = abs(numInputs);
					end
				end
				obj.NumInputArguments = numInputs;
				
				% INCREASE NUMBER OF ARGS FOR VARIABLE-NUM-ARG-IO
				if obj.IsVariableInput
					estimateNumInputs(obj);
				end
				if obj.IsVariableOutput
					estimateNumOutputs(obj);
				end
				
			end
			
		end
		
		
		function anonFcn = getAnonymousFunctionHandle(obj, useAsync)
			% getAnonymousFunctionHandle - Returns anonymous function handle to execute operation
			% Syntax:
			%			>> anonFcn = getAnonymousFunctionHandle(obj, useAsync)
			
			% DEFAULT ASYNC OPTION TO FALSE
			if nargin<2
				useAsync = false;
			end
			
			% CONSTRUCT FUNCTION HANDLE
			if (obj.NumInputArguments > 0)
				argsInABC = num2cell(96+(1:obj.NumInputArguments));
				if (obj.NumInputArguments > 1)
					argsInStr = [sprintf('%c,',argsInABC{1:end-1}),argsInABC{end}];
				else
					argsInStr = char(argsInABC{1});
				end
			else
				argsInStr = '';
			end
			if useAsync
				anonFcn = eval(sprintf('@(%s) parfeval(@%s, %d, %s)' ,...
					argsInStr, char(obj.Function), obj.NumOutputArguments, argsInStr));
			else
				anonFcn = eval(sprintf('@(%s) %s(%s)' , argsInStr, char(obj.Function), argsInStr));
			end
			
			
			
		end
		function args = getFevalArgs(obj, varargin)
			
			if ~isempty(obj.Function)
				fcn = obj.Function;
			else
				fcn = @()[];
			end
			% todo check output matches
			
			% todo check numInputs matches or update
			
			
			args = [ {fcn} , varargin ];
			
		end
		function args = getFevalAsyncArgs(obj, varargin)
			
			if ~isempty(obj.Function)
				fcn = obj.Function;
			else
				fcn = @()[];
			end
			% todo check output matches
			
			% todo check numInputs matches or update
			
			
			args = [ {fcn} , {obj.NumOutputArguments}, varargin ];
			
		end
		
		
		
		% useful perhaps:
		% matlab.depfun.internal.getSig
		% matlab.depfun.internal.builtinSignature
		% getcallinfo
		% addScrapWarning
		function numArgs = estimateNumInputs(obj)
			
			fcn = obj.Function;
			if ~isa(fcn, 'function_handle')
				fcn = ignition.core.FunctionHandle.getMatlabFunctionHandle(fcn);
			end
			
			maxArgs = 16;
			args = num2cell(nan(1,maxArgs)); % todo -> variable type (InputImposter class)
			numArgs = abs(nargin(fcn)); %0; % new
			kNumArgs=numArgs;
			
			while kNumArgs<=maxArgs
				if kNumArgs<1
					evalArgs = {fcn};
				else
					evalArgs = [{fcn}, args(1:kNumArgs) ];
				end
				try
					feval(evalArgs{:});
				catch me
					id = me.identifier;
					% todo -> also check by reading function mfile
					switch id
						case 'MATLAB:UndefinedFunction'
							numArgs = max(numArgs, kNumArgs);
						case 'MATLAB:minrhs'
							numArgs = max(numArgs, kNumArgs);
						case 'MATLAB:structRefFromNonStruct'
							
						case 'MATLAB:structAssToNonStruct'
							
						case 'MATLAB:unassignedOutputs'
							
						case 'MATLAB:maxlhs'
							
						case 'MATLAB:needMoreRhsOutputs'
							
						case 'MATLAB:cellRefFromNonCell'
							%todo
						case 'MATLAB:TooManyInputs'
							numArgs = max(0, kNumArgs-1);
							break
						otherwise
							disp(id)
					end
				end
				kNumArgs=kNumArgs+1;
			end
			
			% REASSIGN PROP IF NO OUTPUT REQUESTED
			if nargout<1
				obj.NumInputArguments = numArgs;
			end
			
		end
		function numArgs = estimateNumOutputs(obj, numIn)
			
			fcn = obj.Function;
			if ~isa(fcn, 'function_handle')
				fcn = ignition.core.FunctionHandle.getMatlabFunctionHandle(fcn);
			end
			if nargin<2
				numIn = obj.NumInputArguments;
			end
			
			if numIn>0
				evalArgs = [{fcn}, num2cell(nan(1,numIn)) ];
			else
				evalArgs = {fcn};
			end
			
			maxArgs = 16;
			numArgs = abs(nargout(fcn)); %0; % new
			kNumArgs=numArgs;
			%numArgs = 0;
			%kNumArgs=0;
			%fcnExcept = struct.empty();
			
			while kNumArgs<=maxArgs
				try
					if kNumArgs>0
						argsOut = cell(1,kNumArgs);
						[argsOut{:}] = feval(evalArgs{:});
					else
						feval(evalArgs{:});
					end
				catch me
					id = me.identifier;
					switch id
						case 'MATLAB:UndefinedFunction'
							numArgs = max(numArgs, kNumArgs);
						case 'MATLAB:minrhs'
							numArgs = max(numArgs, kNumArgs);
						case 'MATLAB:structRefFromNonStruct'
							
						case 'MATLAB:structAssToNonStruct'
							
						case 'MATLAB:cellRefFromNonCell'
							%todo
						case 'MATLAB:TooManyOutputs'
							numArgs = max(0, kNumArgs-1);
							break
						otherwise
							disp(id)
					end
				end
				kNumArgs=kNumArgs+1;
			end
			
			% REASSIGN PROP IF NO OUTPUT REQUESTED
			if nargout<1
				obj.NumOutputArguments = numArgs;
			end
			
		end
		
	end
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
end






% function tasks = createExecutionTasks(obj, taskDependencies, inputFutureMap)
% 		% 4th arg -> isInputReplicated??
%
%
%
% 	end
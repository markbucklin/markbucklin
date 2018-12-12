classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		Operation ...
		< ign.core.FunctionHandle ...
		& ign.core.CustomDisplay ...
		& matlab.mixin.Heterogeneous
	
	
	
	
% 	properties (SetAccess = immutable)
% 		NumInputs
% 		NumOutputs
% 	end
	
	% OPERATION PROPERTIES
	properties (SetAccess = protected)
		%InputArguments = @ign.core.FunctionArgument
		%OutputArguments = @ign.core.FunctionArgument
		NumInputArguments = 0
		NumOutputArguments = 0
		% IOSize, or fcn [numOut, numIn] = iosize(obj) % like InputOutputModel		
	end
	properties (Transient, GetAccess = private, SetAccess = immutable)
		InputCache = []; % parallel.internal.queue.FutureInputHelper??
		OutputCache = []; % parallel.internal.queue.FutureOutputHelper??
	end
	
	properties (SetAccess = protected, Hidden) % immutable) %
		IsVariableInput = false
		IsVariableOutput = false
	end
	
	
	methods
		function obj = Operation(fcn, numInputs, numOutputs)
			
			obj = obj@ign.core.FunctionHandle(fcn);
			
			
			% rather than numInputs/Outputs -> use "NamedInputs"
			% function obj = Operation(fcn, namedInputs, namedOutputs, opAttributes)
			% function obj = Operation(@ign.stat.updateStatistStructure, {'stat_RawGCaMP', 'F_RawGCaMP'},{'stat_RawGCaMP'})
			% if ischar(namedInputs), namedInputs = {namedInputs};
			% if ischar(namedOutputs), namedOutputs= {namedOutputs};
			
			if nargin < 3
				numOutputs = [];
				if nargin < 2
					numInputs = [];
				end
			end
			
			info = obj.Info;
			if isempty(numInputs)
				numInputs = numel(info.InputArgNames);
			end
			if isempty(numOutputs)
				numOutputs = numel(info.OutputArgNames);
			end
			
			obj.NumInputArguments = numInputs;
			obj.NumOutputArguments = numOutputs;
			% 			[obj.InputArguments, obj.OutputArguments] = ...
			% 				ign.core.FunctionArgument.buildFromFunctionInfo(info);
						
			
			
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
		
		
	end
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
end


% 
% % ASSIGN INPUT IF PROVIDED (OR DEFAULT)
% if nargin
% 	
% 	% DETERIMINE/SET NUM-OUTPUT-ARGUMENTS
% 	if nargin > 2
% 		assert(ign.util.isWholeScalar(numOutputs));
% 	else
% 		numOutputs = nargout(obj.Function);
% 		if numOutputs<0
% 			obj.IsVariableOutput = true;
% 			numOutputs = abs(numOutputs);
% 		end
% 	end
% 	obj.NumOutputArguments = numOutputs;
% 	
% 	% DETERIMINE/SET NUM-INPUT-ARGUMENTS
% 	if nargin > 1
% 		assert(ign.util.isWholeScalar(numInputs));
% 	else
% 		numInputs = nargin(obj.Function);
% 		if numInputs<0
% 			obj.IsVariableInput = true;
% 			numInputs = abs(numInputs);
% 		end
% 	end
% 	obj.NumInputArguments = numInputs;
% 	
% 	% INCREASE NUMBER OF ARGS FOR VARIABLE-NUM-ARG-IO
% 	if obj.IsVariableInput
% 		estimateNumInputs(obj);
% 	end
% 	if obj.IsVariableOutput
% 		estimateNumOutputs(obj);
% 	end
% 	
% end


% function tasks = createExecutionTasks(obj, taskDependencies, inputFutureMap)
% 		% 4th arg -> isInputReplicated??
%
%
%
% 	end

classdef FunctionHandle ...
		< ignition.core.Handle
	% FUNCTIONHANDLE - Wrapper class for builtin function_handle
	
	
	
	% FUNCTION-HANDLE PROPERTIES
	properties (SetAccess=immutable)
		FunctionString = ''
	end
	
	properties (SetAccess=immutable, Hidden)
		Function
	end
	
	
	methods
		function obj = FunctionHandle( fcn )
			% FunctionHandle - Construct wrapper for builtin function_handle
			% Usage:
			%			>> obj = ignition.core.FunctionHandle( @fft2 );
			%
			
			if nargin
				
				% RETRIEVE BUILTIN FUNCTION_HANDLE FROM VARIABLE TYPE INPUT
				fcnHandle = ignition.core.FunctionHandle.getMatlabFunctionHandle(fcn);
				
				if iscell(fcnHandle)
					for k=1:numel(fcnHandle)
						obj(k) = ignition.core.FunctionHandle( fcnHandle{k});
					end
					return
					
				else
					% STORE FUNCTION HANDLE IN 'FUNCTION' PROPERTY
					obj.Function = fcnHandle;
					
					% FORMAT AS STRING FOR DISPLAY
					try
						obj.FunctionString = func2str(obj.Function);
					catch
					end
				end
			end
			
			
			
		end
		function varargout = feval(obj, varargin)
			
			
			% 				numIn = nargin - 1; %numel(varargin)
			
			% 			numOut = nargout;
			
			try
				if nargout
					[varargout{1:max(1, nargout)}] = feval(obj.Function, varargin{:});
				else
					feval(obj.Function, varargin{:});
				end
			catch err
				rethrow(err); %todo
				% 				throwAsFunction(obj, err);
			end
			
			% 			if obj.IsVariableOutput
			%
			% 			end
			% 			if obj.IsVariableOutput
			%
			% 		end
			
			
		end
		% function s = functions(obj)
		
		
	end
	methods (Static)
		function matlabFcnHandle = getMatlabFunctionHandle( fcnInput , recursion_flag)
			% getMatlabFunctionHandle - convert variable input to function_handle (builtin matlab class)
			
			% DECLARE PERSISTENT VARIABLE THAT ALLOWS RECURSIVE CALL OF SERIALIZED INPUT
			% 			persistent recursion_flag % todo ignition.util.persistentFlagVariable
			% 			recursion_flag = ignition.util.persistentFlagVariable(recursion_flag);
			if nargin < 2
				recursion_flag = false;
			end
			
			% CHECK TYPE OF FCN-INPUT AND CONVERT
			if isa(fcnInput, 'function_handle')
				% BUILT-IN FUNCTION_HANDLE -> KEEP AS IS
				matlabFcnHandle = fcnInput;
				
			elseif isa(fcnInput, 'ignition.core.FunctionHandle')
				% IGNITION FUNCTIONHANDLE WRAPPER CLASS -> GET VALUE FROM HANDLE PROP
				matlabFcnHandle = fcnInput.Function;
				
			elseif ischar(fcnInput)
				% STRING -> CONVERT TO FUNCTION HANDLE
				matlabFcnHandle = str2func(fcnInput);
				
			elseif isa(fcnInput,'uint8')
				% SERIALIZED INPUT -> DESERIALIZE AND CALL AGAIN
				if ~recursion_flag
					% 					recursion_flag = true;
					matlabFcnHandle = ignition.core.FunctionHandle.getMatlabFunctionHandle(...
						distcompdeserialize(fcnInput) , true);
				else
					me = MException('Ignition:FunctionHandle:getMatlabFunctionHandle:DeserializationFailure',...
						'Failure to obtain convertible class from deserialized input: deserialized class is %s',...
						class(fcnInput));
					throw(me)
				end
				
			elseif iscell(fcnInput)
				%matlabFcnHandle = ignition.util.getFunctionHandlesFromCellArray(fcnInput);
				if ~recursion_flag
					matlabFcnHandle = cellfun(...
						@ignition.core.FunctionHandle.getMatlabFunctionHandle,...
						fcnInput , num2cell(true(size(fcnInput))),'UniformOutput',false);
				else
					me = MException('Ignition:FunctionHandle:getMatlabFunctionHandle:DeserializationFailure',...
						'Failure to obtain convertible class from deserialized input: deserialized class is %s',...
						class(fcnInput));
					throw(me)
				end
				
			else
				% NULL -> HANDLE TO NOOP CLASS-FUNCTION
				matlabFcnHandle = @nullOp;
			end
			
			% ASSERT CORRECT TYPE OUTPUT
			assert( isa(matlabFcnHandle, 'function_handle' ) ,...
				'Ignition:FunctionHandle:getMatlabFunctionHandle:ConversionFailed')
			
			% RESET RECURSION FLAG
			% 			recursion_flag = false;
			
		end		
	end
	
	
	
	
	
	
	
	
end

function varargout = nullOp(varargin)
if nargout
	[varargout{1:nargout}] = [];
end
end




% properties
% NumInputs @double
% NumOutputs @double
% NumInputs @struct  = struct('min',inf,'max',-1,'last',nan)
% NumOutputs @struct = struct('min',inf,'max',-1,'last',nan)
% end



% 			if isempty(obj.NumInputs)
% 				obj.NumInputs = struct('min',inf,'max',-1,'last',nan);
% 				obj.IsVariableInput = true;
% 			end
% 			if isempty(obj.NumOutputs)
% 				obj.NumOutputs = struct('min',inf,'max',-1,'last',nan);
% 				obj.IsVariableOutput = true;
% 			end


%
% 	function throwAsFunction(obj, err)
% 	import matlab.bigdata.BigDataException;
% 	err = BigDataException.hAttachSubmissionStack(err, obj.ErrorStack);
%
% 	% This error is a wrapper to separate user errors from
% 	% execution errors. This will be unwrapped by
% 	% parseExecutionError at the top level.
% 	iErr = MException(message('MATLAB:bigdata:array:FunctionHandleError'));
% 	iErr = addCause(iErr, err);
% 	throw(iErr);
% 	end


% 		function validNumInputs = tryNumInputRange( fcn, numInputRange )
%
% 			% todo -> inputTypes, or create class that provides
% 			%			IOSpec (idx,validtypes,isoptional, validnumdims, validsizes)
% 			try
% 				fhException=MException.empty;
% 				argsOut = cell(1,1);
% 				[argsOut{:}] = feval(@fft,magic(64));
% 			catch me
% 				fhException=me;
% 			end
%
% 		end




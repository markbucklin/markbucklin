classdef FunctionHandle ...
		< ign.core.Handle
	% FUNCTIONHANDLE  Wrapper class for builtin function_handle
	
	
	
	% FUNCTION-HANDLE PROPERTIES
	properties (SetAccess=immutable)
		String = ''
		Info
		ArgInInfo
		ArgOutInfo		
	end
	
	properties (SetAccess=immutable, Hidden)
		Function % function_handle
	end
	
	
	methods
		function obj = FunctionHandle( fcn )
			% FunctionHandle - Construct wrapper for builtin function_handle
			% Usage:
			%			>> obj = ign.core.FunctionHandle( @fft2 );
			%
			
			if nargin
				
				% IF INPUT IS SAME CLASS COPY & RETURN
				if isa(fcn, 'ign.core.FunctionHandle')					
					obj.String = fcn.String;
					obj.Info = fcn.Info;
					obj.Function = fcn.Function;					
					return
				end
				
				% RETRIEVE BUILTIN FUNCTION_HANDLE FROM VARIABLE TYPE INPUT				
				fcn = ign.core.FunctionHandle.getMatlabFunctionHandle(fcn);
				
				if iscell(fcn)
					for k=1:numel(fcn)
						obj(k) = ign.core.FunctionHandle( fcn{k});
					end
					return
					
				else
					% STORE FUNCTION HANDLE IN 'FUNCTION' PROPERTY
					obj.Function = fcn;
										
					% GET STRING USING FUNC2STR
					str = func2str(fcn);
					obj.String = str;
					
					% STORE INFORMATION OBJECT (USE CACHE IF POSSIBLE)
					info = ign.util.accessNamedCacheVariable('ign.core.FunctionHandle',str);% todo: move to pkg
					if isempty(info)
						info = ign.core.FunctionInfo(fcn);
						ign.util.accessNamedCacheVariable('ign.core.FunctionHandle',str, info) % todo: move to pkg
					end
					obj.Info = info;
					
					[obj.ArgInInfo, obj.ArgOutInfo] = ...
						ign.core.ArgumentInfo.buildFromFunctionInfo(info);
										
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
	methods (Static, Hidden)		
		function fcn = getMatlabFunctionHandle( fcnInput , recursion_flag)
			% getMatlabFunctionHandle - convert variable input to function_handle (builtin matlab class)
			
			% DECLARE PERSISTENT VARIABLE THAT ALLOWS RECURSIVE CALL OF SERIALIZED INPUT
			if nargin < 2
				recursion_flag = false;
			end
			
			% CHECK TYPE OF FCN-INPUT AND CONVERT
			if isa(fcnInput, 'function_handle')
				% BUILT-IN FUNCTION_HANDLE -> KEEP AS IS
				fcn = fcnInput;
				
			elseif isa(fcnInput, 'ign.core.FunctionHandle')
				% IGN FUNCTIONHANDLE WRAPPER CLASS -> GET VALUE FROM HANDLE PROP
				fcn = fcnInput.Function;
				
			elseif ischar(fcnInput)
				% STRING -> CONVERT TO FUNCTION HANDLE
				fcn = str2func(fcnInput);
				
			elseif isa(fcnInput,'uint8') % todo -> check functional
				% SERIALIZED INPUT -> DESERIALIZE AND CALL AGAIN
				if ~recursion_flag
					% 					recursion_flag = true;
					fcn = ign.core.FunctionHandle.getMatlabFunctionHandle(...
						distcompdeserialize(fcnInput) , true);
				else
					me = MException('Ign:FunctionHandle:getMatlabFunctionHandle:DeserializationFailure',...
						'Failure to obtain convertible class from deserialized input: deserialized class is %s',...
						class(fcnInput));
					throw(me)
				end
				
			elseif iscell(fcnInput)
				if ~recursion_flag
					fcn = cellfun(...
						@ign.core.FunctionHandle.getMatlabFunctionHandle,...
						fcnInput , num2cell(true(size(fcnInput))),'UniformOutput',false);
				else
					me = MException('Ign:FunctionHandle:getMatlabFunctionHandle:DeserializationFailure',...
						'Failure to obtain convertible class from deserialized input: deserialized class is %s',...
						class(fcnInput));
					throw(me)
				end
				
			else
				% NULL -> HANDLE TO NOOP CLASS-FUNCTION
				fcn = @nullOp;
			end
			
			% ASSERT CORRECT TYPE OUTPUT
			assert( isa(fcn, 'function_handle' ) ,...
				'Ign:FunctionHandle:getMatlabFunctionHandle:ConversionFailed')
			
			% RESET RECURSION FLAG
			% 			recursion_flag = false;
			
		end
		function numArgs = estimateNumInputs( fcn )
		% todo -> fix and find usefulness or remove
			
			fcn = ign.core.FunctionHandle.getMatlabFunctionHandle(fcn);
			
			maxArgs = 16;
			args = num2cell(nan(1,maxArgs)); % todo -> variable type (InputImposter class)
			numArgs = 0; % abs(nargin(fcn)); %0; % new
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
						case 'MATLAB:nonaninf'
							args = num2cell(ones(1,maxArgs));
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
			
			
		end
		function numArgs = estimateNumOutputs(fcn, numIn)
			
			fcn = ign.core.FunctionHandle.getMatlabFunctionHandle(fcn);
			
			if nargin<2
				numIn = nargin(fcn);
			end
			
			if numIn>0
				evalArgs = [{fcn}, num2cell(nan(1,numIn)) ];
			else
				evalArgs = {fcn};
			end
			
			maxArgs = 16;
			numArgs = 0; % abs(nargout(fcn));
			kNumArgs=numArgs;
			
			while kNumArgs<=maxArgs
				try
					if kNumArgs>0
						argsOut = cell(1,kNumArgs);
						[argsOut{:}] = feval(evalArgs{:});						
					else
						feval(evalArgs{:});
					end
					numArgs = numel(argsOut);
				catch me
					id = me.identifier;
					switch id
						case 'MATLAB:UndefinedFunction'
							%numArgs = max(numArgs, kNumArgs);
						case 'MATLAB:minrhs'
							%numArgs = max(numArgs, kNumArgs);
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
			
		end
	end
	
	
	
	
	properties (Constant, Hidden)
		MaxNumArgs = 31
	end
	
	
	
end

function nullOp()
end





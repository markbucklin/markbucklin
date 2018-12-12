classdef (CaseInsensitiveProperties, TruncatedProperties, HandleCompatible) ...
		FunctionArgument
	
	% replaced by ArgumentInfo -> make a data container
	
	
	properties (SetAccess = protected)
		Name
		Idx
		IsInput
		IsOutput
		Type = {''}
	end
	
	
	
	
	methods
		% CONSTRUCTOR
		function obj = FunctionArgument(name,idx,in,out) % type (todo)
			
			if nargin
				% DEFAULT 4TH & 5TH INPUT
				if (nargin < 4), out = ~in; end
				if (nargin < 5), type = {''}; end					
				
				obj.Name = name;
				obj.Idx = idx;
				
				obj.IsInput = in;
				obj.IsOutput = out;
				
				%obj.Type = type;
				
				% 				% GET TYPE
				% 				isIn = ~isempty(strfind(type,'in'));
				% 				isOut = ~isempty(strfind(type,'out'));
				% 				if isIn && isOut
				% 					obj.Type = 'in/out';
				% 				elseif isIn
				% 					obj.Type = 'in';
				% 				elseif isOut
				% 					obj.Type = 'out';
				% 				else
				% 					error('Must specify FunctionArgument type as ''in'', ''out'', or ''in/out''');
				% 				end
			end
			
		end
	end
	methods (Static)
		function [argsIn, argsOut] = buildFromFunctionInfo(info)
			
			% INITIALIZE
			argsIn = ign.core.FunctionArgument.empty;
			namesIn = info.InputArgNames;
			argsOut = ign.core.FunctionArgument.empty;
			namesOut = info.OutputArgNames;
			
			% INPUTS
			k=0;
			outIsIn = zeros(size(namesOut));
			while k<numel(namesIn)
				k = k + 1;
				name = namesIn{k};
				matchOut = strcmp(name,namesOut);
				if any(matchOut)
					outIdx = find(matchOut,1,'first');
					outIsIn(outIdx) = k;
					%argsIn(k) = ign.core.FunctionArgument(name,k,'in/out');
					argsIn(k) = ign.core.FunctionArgument(name,k,true,true);
				else
					outIsIn(k) = 0;
					%argsIn(k) = ign.core.FunctionArgument(name,k,'in');
					argsIn(k) = ign.core.FunctionArgument(name,k,true,false);
				end
			end
			
			% OUTPUTS
			k=0;
			
			while k<numel(namesOut)
				k = k + 1;
				name = namesOut{k};
				if outIsIn(k) > 0;
					argsOut(k) = argsIn(outIsIn(k));
				else
					%argsOut(k) = ign.core.FunctionArgument(name,k,'out');
					argsOut(k) = ign.core.FunctionArgument(name,k,false,true);
				end
			end
			
		end
	end
	
	
	
	
	
	
	
	
	
	
	
	
	
	
end



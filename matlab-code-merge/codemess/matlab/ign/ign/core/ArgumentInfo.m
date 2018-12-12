classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		ArgumentInfo ...
		< ign.core.Handle ...
		& ign.core.CustomDisplay
	
	
	
	% FUNCTION ARGUMENT DESCRIPTORS
	properties (SetAccess = protected)				
		Idx = 0
		Name = ''		
		Type = {''}
	end
	
	properties (SetAccess = protected)		
		IsRequired = false
		IOType
	end
	
	
	
	
	
	
	
	methods
		function obj = ArgumentInfo( idx, name, type)
				
			if nargin
				% DEFAULT TYPE				
				if (nargin < 3), type = {''}; end					
				
				obj.Idx = idx;
				obj.Name = name;								
				obj.Type = type;
				
			end
		
		end
		function obj = addAlias(obj, alias)
			% todo
		end
	end
	methods (Static)
		function [argsIn, argsOut] = buildFromFunctionInfo(info)
			
			% INITIALIZE
			argsIn = ign.core.InputArgumentInfo.empty;
			namesIn = info.InputArgNames;
			argsOut = ign.core.OutputArgumentInfo.empty;
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
				else
					outIdx = 0;
					outIsIn(k) = 0;										
				end				
				argsIn(k) = ign.core.InputArgumentInfo(k,name);
			end
			
			% OUTPUTS
			k=0;
			
			while k<numel(namesOut)
				k = k + 1;
				name = namesOut{k};
				argsOut(k) = ign.core.OutputArgumentInfo(k,name); % todo: type
				if outIsIn(k) > 0;
					bindMatchingOutput(argsIn(outIsIn(k)), argsOut(k));
					bindMatchingInput(argsOut(k),argsIn(outIsIn(k)));
				end
			end
			
		end
	end
	
	
	
end
classdef Handle ...
		< ign.core.Object ...
		& handle
	
	
		
	
	
	% CONSTRUCTOR
	methods
		function obj = Handle(varargin)		
			% PARSE USING COMMON/PARENT OBJECT CONSTRUCTOR
			obj = obj@ign.core.Object(varargin{:});
			
		end
	end
	
	% INITIALIZATION HELPER METHODS
	methods (Access = protected, Hidden)
		function structOutput = updateFieldsFromProps(obj, structInput)
			fn = fields(structInput);
			for kf = 1:numel(fn)
				try
					structOutput.(fn{kf}) = obj.(fn{kf});
				catch
					structOutput.(fn{kf}) = structInput.(fn{kf});
				end
			end
			% todo: make Upper/lowerCamelCase insensitive
		end
		function structOutput = updateFieldsFromPropsCaseInsensitive(obj, structInput)
			fieldNames = fields(structInput);
			%propNames = properties(obj);
			
			% todo
			%fieldMatch = cellfun(@(c,s) find(strcmpi(c,s),1,'first'),...
			%	repmat({propNames},numel(fieldNames),1), fieldNames);
			
			for kf = 1:numel(fieldNames)
				try
					structOutput.(fieldNames{kf}) = obj.(fieldNames{kf});
				catch
					structOutput.(fieldNames{kf}) = structInput.(fieldNames{kf});
				end
			end
			
			% 			function fpMatch = anyCaseMatch
			% todo: make Upper/lowerCamelCase insensitive
		end
	end
	
	
	
	
end






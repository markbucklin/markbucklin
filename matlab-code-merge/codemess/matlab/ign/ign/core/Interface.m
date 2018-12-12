classdef Interface ......
		< ign.core.Unique ...
		& ign.core.CustomDisplay ...
		& ign.core.Handle ...
		& matlab.mixin.Heterogeneous
	
	
	properties
		Name
	end
	properties (SetAccess = protected)
		%UniqueName % todo -> or use (Unique) StandardName
		Alias = {}
	end
	

	
	
	methods
		function addAlias(obj, alias)
			if ischar(alias)
				obj.Alias{end+1} = alias;
			elseif iscellstr(alias)
				obj.Alias = [obj.Alias , alias];
			end			
		end
	end
	
	
	
	
end

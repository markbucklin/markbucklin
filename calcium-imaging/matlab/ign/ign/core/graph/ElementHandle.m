classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		ElementHandle ...
		< ign.core.graph.Element ...
		& ign.core.Handle
	
	
	
	properties (SetAccess = protected)
		ElementObj @ign.core.graph.Element
		Type
	end
	
	
	methods
		function obj = ElementHandle(el)
			
			if numel(el) == 1				
			% STORE ORIGINAL ELEMENT
			obj.ElementObj = el;
			obj.Type = class(el);
			
			% REPLICATE ID & ATTRIBUTE
			obj.ID = el.ID;
			obj.AttributeSet = el.AttributeSet;
			
			else
				for k = 1:numel(el)
					obj(k) = ign.core.graph.ElementHandle(el(k));
				end
				return
			end
			
		end
		function el = update(obj, el)
			% todo expand
			obj.ElementObj = el;
		end
		
	end
	
end















%
% % FORM ATTRIBUTE-SET AS NAME-VAL PAIRS
% 				attrSet = attrSetList{k};
% 				attrName = keys(attrSet);
% 				attrVal = values(attrSet);
% 				elArg = [attrName(:)' ; attrVal(:)'];
% 				obj(k) = obj(k)@ign.core.graph.Element( id, elArg{:});
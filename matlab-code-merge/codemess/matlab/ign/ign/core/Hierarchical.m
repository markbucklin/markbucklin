classdef (CaseInsensitiveProperties, TruncatedProperties, HandleCompatible) ...
		Hierarchical ...
		< matlab.mixin.Heterogeneous ...
		& ign.core.Handle
	
	
	
	properties (SetAccess = {?ign.core.Object})
		Parent @ign.core.Hierarchical
		Children @ign.core.Hierarchical
	end
	
	% HIERARCHY BUILDING/MANIPULATION
	methods
		function parent = addChild(parent, child)
			
			% SET PARENT OF ALL GIVEN CHILDREN TO CURRENT OBJECT
			if isa(child,'ign.core.Hierarchical')
				if numel(child) == 1
					child.Parent = parent;
				else
					[child.Parent] = deal(parent);
				end
			end
			
			% ASSIGN CHILD(REN) TO CURRENT OBJECT			
			if isempty(parent.Children)
				parent.Children = child;
			elseif ~any(parent.Children == child)
				parent.Children(end+1) = child;
			end
			
		end
		function parent = removeChild(parent, child)
			
			% REMOVE CHILD FROM CUSTODY OF CURRENT OBJECT
			isChild = any(parent.Children(:) == child(:)', 2);
			if any(isChild)
				parent.Children(isChild) = [];
			end
			
			% REMOVE PARENT FROM CHILD -> INITIALIZE TO EMPTY
			if isa(child,'ign.core.Hierarchical')
				isParent = any(child.Parent(:) == parent',2);
				if any(isParent)
					[child(isParent).Parent(1)] = deal(ign.core.Hierarchical.empty());
				end
			end
			
		end
		function child = setParent(child, parent)
			% REQURE BOTH PARENT & CHILD ARE HIERARCHICAL CLASS
			assert( isa(parent,'ign.core.Hierarchical') && isa(child,'ign.core.Hierarchical'))
			
			k = 1;
			while k <= numel(child)
				
				% CHECK REDUNDANT PARENTAL ASSIGNMENT
				priorParent = child(k).Parent;
				if isequal(priorParent, parent), return, end
				
				% REMOVE CURRENT OBJECT FROM PRIOR PARENT CUSTODY
				if ~isempty(priorParent)
					priorParent.Children(priorParent.Children == child(k)) = [];
				end
				
				% GIVE NEW PARENT CUSTODY OF CURRENT OBJECT
				parent.Children(end+1) = child(k);
				
				% ASSIGN NEW PARENT TO CURRENT OBJECT
				child(k).Parent = parent;
				
				k = k + 1;
			end
			
		end
	end
	
	% HIERARCHY QUERY
	methods
		function root = getRoot(obj)
			ancestors = getAncestors(obj);
			if ~isempty(ancestors)
				root = ancestors(1);
			else
				root = obj;
			end
		end
		function ancestors = getAncestors(obj)
			parent = obj.Parent;
			ancestors = parent;
			while ~isempty(parent) && isa(parent,'ign.core.Hierarchical')
				parent = parent.Parent;
				ancestors = [parent; ancestors];
			end
			
		end
		function descendents = getDescendents(obj)
						
			descendents = obj.Children([]);
			%descendents = [descendents ; getChildren(descendents)];
			getChildren(obj.Children)
			
			function getChildren(children)
				if isempty(children)					
					return
				end
				
				for k = 1:numel(children)
					% APPEND EACH CHILD TO GROWING LIST OF DESCENDENTS
					child = children(k);
					descendents = [descendents ; child];
					
					% RECURSIVELY SEARCH EACH CHILD
					if isa(child,'ign.core.Hierarchical')
						getChildren(child.Children)						
					end
				end
				
				% 				while ~isempty(child) && isa(child,'ign.core.Hierarchical')
				% 					children = children.Children;
				% 					descendents = [children; descendents];
				% 				end
			end
		end
		function [common, splitA, splitB] = getCommonAncestor( childA, childB)
			
			ancA = getAncestors(childA);
			ancB = getAncestors(childB);
			
			% GET EQUIVALENCE MATRIX TO FIND COMMON ANCESTOR
			try
				match = ancA == ancB';
			catch
				if numel(ancA) < numel(ancB)
					for k = numel(ancA):-1:1
						match(:,k) = (ancA(k) == ancB);
					end
					match = match';
				else
					for k = numel(ancB):-1:1
						match(:,k) = (ancA == ancB(k))';
					end
				end
			end
			commonMatchA = any(match, 2);
			commonMatchB = any(match, 1);
			
			intersectionIdxA = find(commonMatchA, 1, 'last');
			intersectionIdxB = find(commonMatchB, 1, 'last');
			
			splitA = ancA((intersectionIdxA+1):end);
			splitB = ancB((intersectionIdxB+1):end);
			common = ancA(1:intersectionIdxA);
			
		end
		function [branch, common, b1, b2] = getCommonBranch( h1, h2)
			assert(isa(h1,'ign.core.Hierarchical') && isa(h2,'ign.core.Hierarchical'))
			b1 = [getAncestors(h1); h1];
			b2 = [getAncestors(h2); h2];
			
			ancMatch = any( eq(b1, b2'), 2);
			
			
			if any(ancMatch)
				common = b1(ancMatch);
				branch = common(end);
			else
				common = ign.core.Hierarchical.empty();
				branch = common;
			end
			
		end
	end

	
	
	
end


















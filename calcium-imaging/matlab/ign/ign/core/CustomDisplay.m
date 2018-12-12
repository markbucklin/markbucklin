classdef (HandleCompatible) CustomDisplay < matlab.mixin.CustomDisplay
	
	
	
	
	
	methods (Access = protected)
		function propGroups = getPropertyGroups(obj)
			
			%% (NEW) ATTEMPT TO RETRIEVE PROPERTY GROUPS FROM PERSISTENT CACHED MAP
			persistent propGroupCache propListFailFast
			
			% INITIALIZE PERSISTENT CACHE -> HASH-MAP WHERE KEY=PACKAGEDCLASSNAME
			propGroupCache = ign.util.persistentMapVariable(propGroupCache);
			className = class(obj);
			cacheKey = strrep(className,'.','_');
			
			% USE LIST OF PUBLIC PROPERTIES (FAST/BUILTIN) TO INDICATE CLASS-DEFINITION
			propListFailFast = ign.util.persistentMapVariable(propListFailFast);
			publicPropList = properties(obj);
			publicPropHashVec = 0 + double([publicPropList{:}]);
			
			% CHECK FOR CHANGES WITH FAST-FAIL COMPARISON TO CACHED PROP-LIST
			try
				useCache = false;
				if iskey(propListFailFast,cacheKey) ...
						&& (propListFailFast(cacheKey) == publicPropHashVec) ...
						&& iskey(propGroupCache,cacheKey)
					useCache = true;
				end
			catch
			end
			
			% USE CACHE -> RETRIEVE CACHED PROPERTY-GROUPS & RETURN EARLY
			if useCache
				propGroups = propGroupCache(cacheKey);
				return
			end
			
			%% CACHE-MISS -> BUILD PROPERTY-GROUPS FROM METAINFO & COMMENTS CLASS-DEFINITION-FILE
			propGroupLabelMap = containers.Map;
			
			% GET METACLASS OF CALLING OBJECT
			mobj = metaclass(obj);
			metaObjectHeirarchy = mobj;
			
			% GET TOP PACKAGE
			pkg = mobj.ContainingPackage;
			while ~isempty(pkg.ContainingPackage)
				pkg = pkg.ContainingPackage;
			end
			parentPackageName = pkg.Name;
			
			% GET SUPERCLASSES OF CALLING OBJECT
			superNames = superclasses(obj);
			for kSuper=1:numel(superNames)
				msuper = meta.class.fromName(superNames{kSuper});
				if ~isempty(msuper.ContainingPackage)
					pkgMatch =  strncmpi( parentPackageName,...
						msuper.ContainingPackage.Name, numel(parentPackageName));
					if pkgMatch
						metaObjectHeirarchy = [metaObjectHeirarchy ; msuper];
					end
				end
			end
			
			% CATEGORIZE PROPERTIES FROM EACH INHERITED CLASS
			% 			for kObj=1:numel(metaObjectHeirarchy)
			kObj = numel(metaObjectHeirarchy);
			groupKeyIdx = cell(1,kObj);
			while kObj >= 1
				
				% EXTRACT LABELS FROM COMMENT ABOVE PROPERTY BLOCKS IN CLASS-CODE
				propBlocks = ign.util.getLabeledPropertyBlocks(...
					metaObjectHeirarchy(kObj).Name);
				
				for kBlock=1:numel(propBlocks)
					
					% FOR EACH COMMENT-LABEL ABOVE A PROPERTIES DEFINITION BLOCK
					blockLabel = propBlocks(kBlock).Label;
					if isempty(blockLabel)
						continue
					end
					
					% (NEW) CHANGE FROM ALL-CAPS TO FIRST LETTER CAP
					isFirstLetter = regexp(blockLabel, '\<\w*');
					blockLabel = lower(blockLabel);
					blockLabel(isFirstLetter) = upper(blockLabel(isFirstLetter));
					
					% ADD TO CURRENT LABELS IF NECESSARY
					if ~isKey(propGroupLabelMap, blockLabel)
						propGroupLabelMap(blockLabel) = propBlocks(kBlock).Properties;
					else
						currentProps = propGroupLabelMap(blockLabel);
						newProps = propBlocks(kBlock).Properties;
						propGroupLabelMap(blockLabel) = [currentProps newProps];
					end
										
					% (NEW) STORE KEYS IN HIERARCHY ORDERED LIST
					groupKeyIdx{kObj} = blockLabel;
				end				
				
				kObj = kObj - 1;
			end
			
			% CONSTRUCT PROPERTY-GROUPS
			%groupKeys = keys(propGroupLabelMap);
			groupKeys = groupKeyIdx(~cellfun(@isempty, groupKeyIdx));
			if numel(groupKeys) >= 1
				for kGroup = 1:numel(groupKeys)
					
					% PROP-GROUP-LABEL-MAP KEY (BLOCK-LABEL) -> TITLE
					groupLabel = groupKeys{kGroup};
					
					% PROP-GROUP-LABEL-MAP VALUE (PROPERTIES) -> PROPERTY-LIST
					groupPropList = propGroupLabelMap(groupLabel);
					
					% BUILD GROUP OBJECT -> (builtin) PROPERTYGROUP CLASS CONSTRUCTOR
					%propGroups(kGroup) = matlab.mixin.util.PropertyGroup(...
					%	groupPropList, groupLabel);
					
					boldLabel = sprintf('<strong>%s</strong>',groupLabel);
					
					% 					['<a href="" ',...
					% 						'style="',...
					% 						'font-weight:bold">',...
					% 						'%s</a>'],...
					
					propGroups(kGroup) = matlab.mixin.util.PropertyGroup(...
						groupPropList, boldLabel);
					
					%propGroups(kGroup).Aligned = false;
				end
				
			else
				propGroups = matlab.mixin.util.PropertyGroup.empty;
				
			end
			
			%% SORT
			
			%% (NEW) UPDATE CACHED PROPERTY-GROUPS & CLASS-DEFINITION CHANGE INDICATOR
			propGroupCache(cacheKey) = propGroups;
			propListFailFast(cacheKey) = publicPropHashVec;
			ign.core.CustomDisplay.getSetStaticCache(propGroupCache);
			
			
		end
		function s = getStructFromPropGroup(obj, propGroupName)
			% getStructFromPropGroup - Return structure of properties belonging to specified group
			%		Usage:
			%			>> s = getStructFromPropGroup(obj, propGroupName)
			%
			%		Note: propGroupName is case-insensitive and can be expressed with wildcard (e.g. 'CON*')
			
			try
				%s = struct.empty();
				allPropGroups = getPropertyGroups(obj);
				
				if ischar(propGroupName)
					
					% REMOVE BOLD FORMATTING
					% 					propGroupName = strrep( strrep(propGroupName,...
					% 						'<strong>',''), '</strong>', '');
					propGroupTagList = {allPropGroups.Title};
					removeBoldFcn = @(tag) strrep(strrep(tag,'<strong>',''),'</strong>','');
					propGroupTagList = cellfun( removeBoldFcn, propGroupTagList, 'UniformOutput',false);
					
					if (propGroupName(end) == '*')
						% todo
					else
						isGroup = strcmpi(propGroupName,propGroupTagList);
						
					end
				elseif iscellstr(propGroupName)
					% CALL RECURSIVELY TO RETURN CELL ARRAY OF MULTIPLE STRUCTS
					s = cellfun(@(name)getStructFromPropGroup(obj,name),...
						propGroupName, 'UniformOutput',false);
					return
				end
				
				propGroup = allPropGroups(isGroup);
				propList = [propGroup.PropertyList];
				if isempty(propList)
					s = struct.empty();
					return
				end
				for k=1:numel(propList)
					try
						propName = propList{k};
						s.(propName) = obj.(propName);
					catch
					end
				end
			catch
				s = struct.empty();
			end
			
		end
	end
	
	methods (Access = public, Hidden)
		function [propGroups, varargout] = getCustomPropertyGroups(obj)
			% publicly accessible backdoor method to access getPropertyGroups method (defined with
			% 'Access=protected' attribute in matlab.mixin.CustomDisplay class)
			
			% CALL PROTECTED METHOD
			propGroups = getPropertyGroups(obj);
			
			% RETURN CURRENT PROPERTY-GROUP PERSISTENT CACHE IF 2ND OUTPUT REQUESTED
			if (nargout > 1)
				varargout{1} = ign.core.CustomDisplay.getSetStaticCache();
			end
			
		end
	end
	methods (Access = private, Static, Hidden)
		function varargout = getSetStaticCache(varargin)
			% getSetStaticCache - update or retrieve latest update to static cache for all instances
			
			persistent staticCache
			if nargin
				staticCache = varargin{1};
			end
			if nargout
				varargout{1} = staticCache;
			end
			
		end
	end
	
	
	
	
end

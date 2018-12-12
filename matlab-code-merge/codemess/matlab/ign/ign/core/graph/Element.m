classdef (CaseInsensitiveProperties, TruncatedProperties, HandleCompatible) ...
		Element ...
		< matlab.mixin.Heterogeneous ...
		& ign.core.CustomDisplay
	
	
	% ELEMENT PROPERTIES
	properties (SetAccess = protected)
		ID
	end
	
	properties (SetAccess = protected)
		AttributeSet = containers.Map('KeyType','char','ValueType','any')
	end
	properties (Transient)
		%Graph @ign.core.graph.Graph
	end
	
	
	
	
	% CONSTRUCTION
	methods
		function obj = Element( id, varargin)
			% obj = Element('ID',1,'Name','basicelement5','Visible',true)
			
			if nargin
				% ASSIGN ID
				if iscell(id)
					% ALLOW MULTIPLE CONSTRUCTION
					for k = 1:numel(id)
						obj(k) = ign.core.graph.Element( id{k}, varargin{:});
					end
					return
				else
					obj.ID = id;
				end
				
				
				% CUSTOM ATTRIBUTE ARGUMENTS IN PROP-VAL PAIRS
				numArgs = numel(varargin);
				if numArgs > 1
					k = 1;
					%customAttr = initializeAttributeSet(obj);
					attrSet = obj.AttributeSet;
					while k < numArgs
						prop = varargin{k};
						val = varargin{k+1};
						try
							obj.(prop) = val;
						catch
							attrSet(prop) = val;
						end
						k = k + 2;
					end
					obj.AttributeSet = attrSet;
					
				end
			end
			
			% GENERATE ID AUTOMATICALLY IF UNSPECIFIED
			if isempty(obj.ID)
				elementType = ign.util.getClassName(obj);
				instanceCounter = getSharedCounter(elementType);
				instanceCounter.increment()
				cnt = instanceCounter.get();
				obj.ID = cnt;
				
			end
			
		end
		function el = getHandle(obj)
			if isa(obj, 'handle')
				el = obj;
			else
				el = ign.core.graph.ElementHandle(obj);
			end
		end
	end
	
	% GRAPH INTERFACE
	methods
	end
	
	% ID MANAGEMENT
	methods
		function [element, index] = findElement( elementArray, varargin)
			
			switch nargin
				case 2
					element = varargin{1};
					index = find( elementArray == element);
					return
				case 3
					name = varargin{1};
					value = varargin{2};			
			end
			elementCount = numel(elementArray);
			
			try
				% TRY TO GET PROPERTY
				cval = {elementArray.(name)};
				valMatch = cellfun(@(q) isequal(q,value), cval);				
				index = find(valMatch);
				element = elementArray(valMatch);
				
			catch
				% PERHAPS NAME REFERS TO KEY IN ATTRIBUTEMAP				
				attrMapSet = {elementArray.AttributeSet};
				hasProp = cellfun(@(attrmap) isKey(attrmap,name), attrMapSet);
				attrMapSet = attrMapSet(hasProp);
				cval = cellfun(@(attrmap) attrmap(name), attrMapSet, 'UniformOutput', false);				
				index = find(hasProp);
				element = elementArray(index);
				if ~isempty(index)								
					valMatch = cellfun(@(ev)isequal(ev,value), cval);					
					index = index(valMatch);
					element = element(valMatch);
				end
			end
		end
		function isMatch = matchID( el, id)
			if isnumeric(id)
				
			elseif ischar(id)
				
			elseif iscell(id)
				
			end
		end
		function index = findIndex( el, id)
			
		end
	end
	
	% ATTRIBUTE MANAGEMENT
	methods
		function obj = addAttribute( obj, name, val)
			if nargin < 3
				val = [];
			end
			if ischar(name)
				obj.Attribute(name) = val;
			elseif iscellstr(name)
				for k=1:numel(name)
					obj.Attribute(name{k}) = val;
				end
			end
			
		end
	end
	methods (Hidden)
		% 		function attrSet = initializeAttributeSet(~)
		% 			attrSet = containers.Map('KeyType','char','ValueType','any');
		% 			% todo initializeAttributeSet( obj, keys, values)
		% 			% -> call using initializeAttributeSet( obj, varargin(1:2:end), varargin(2:2:end))
		% 		end
	end
	
	
	
end





% % GENERATE ID & NAME AUTOMATICALLY IF UNSPECIFIED
% 			autoID = isempty(obj.ID);
% 			autoName = isempty(obj.Name);
%
% 			if autoID || autoName
% 				elementType = ign.util.getClassName(obj);
% 				instanceCounter = getSharedCounter(elementType);
% 				instanceCounter.increment()
% 				cnt = instanceCounter.get();
%
% 				% AUTOMATIC NAMING: '<CLASSNAME><INSTANCENUM>'
% 				if autoName
% 					obj.Name = sprintf('%s%d', elementType, cnt);
% 				end
%
% 				if autoID
% 					obj.ID = cnt;
% 				end
%
% 			end

%
% 			% ALLOW MULTIPLE CONSTRUCTION
% 			if iscellstr(name)
% 				for k = 1:numel(name)
% 					obj(k) = ign.core.graph.Element(name{k},elementType,varargin{:});
% 				end
% 				return
% 			end
%
% if ~isempty(varargin)
% 				for k=1:2:numel(varargin)
% 					attr = varargin(k:(max(numel(vararing),k+1)));
% 					obj = addAtribute(obj, attr{:});
% 				end
% 			end
%
% 			% DEFAULT ID: '' (empty until added to graph)
% 			if (nargin < 3)
% 				id = '';
% 			end

% 			obj.ID = id;


%
%
%
% 			if nargin
% 				obj.Name = name;
% 				if nargin > 1
% 					obj.Type = type;
% 				else
% 					obj.Type = ign.util.getClassName(obj);
% 				end
% 			end
%

% function className = getClassName(obj)
%
% try
% 	fullClassName = strsplit(class(obj), '.');
% 	className = fullClassName{end};
% catch
% 	className = '';
% end
% end

% INHERITED PROPERTIES
% Unique:
%		ID
%		NumericID (hidden)
%		UniqueName (hidden)
%	Hierarchical
%		Parent
%		Children


%
% % DEFAULT TYPE: '<CLASSNAME>'
% 			if (nargin < 2) || isempty(type)
% 				type = ign.util.getClassName(obj);
% 			end
%
% 			% DEFAULT NAME: '<CLASSNAME>:<INSTANCENUM>'
% 			if (nargin < 1) || isempty(name)
% 				unnamedInstanceCount = getSharedCounter(type);
% 				unnamedInstanceCount.increment()
% 				name = sprintf('%s%d',type,unnamedInstanceCount.get());
% 			end
%
% 			% ALLOW MULTIPLE CONSTRUCTION
% 			if iscellstr(name)
% 				for k = 1:numel(name)
% 					obj(k) = ign.core.graph.Element(name{k},type,varargin{:});
% 				end
% 				return
% 			end
%
% 			% ASSIGN PROPERTIES
% 			obj.Name = name;
%
% 			if ~isempty(varargin)
% 				for k=1:2:numel(varargin)
% 					attr = varargin(k:(max(numel(vararing),k+1)));
% 					obj = addAtribute(obj, attr{:});
% 				end
% 			end
%





% DEFAULT ARGUMENT PARSING
% 			obj = obj@ign.core.Object(varargin{:});
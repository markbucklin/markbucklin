classdef (CaseInsensitiveProperties, TruncatedProperties, HandleCompatible)...
		Graph ...
		< ign.core.graph.Node ...
		& ign.core.Handle
	
	
	% GRAPH PROPERTIES
	properties
		
		NodeList @ign.core.graph.Node
		EdgeList @ign.core.graph.Edge
		
	end

	
	
	
	methods (Access = protected)
		function obj = Graph()
			
		end
	end
	methods
		function addNode(obj, node)
			m = numel(node);
			for k=1:numel(obj)
				%obj(k).NodeList = [obj(k).NodeList(:) ; node(:)];
				obj(k).NodeList(end+1 : end+m) = node;
			end
		end
		function removeNode(obj, node)
			
		end
		function addEdge(obj, sourceNode, targetNode)
			% addEdge(obj, sourceNode, targetNode)
			
		end
		function removeEdge(obj, edge)
			
		end
	end
	
	
	methods (Static)
		function g = getCurrentInstance()
			g = accessPersistentHandleStore('current');
		end
		function g = getNewInstance(name) % todo: name
			if nargin<1
				name = [];
			end
			g = accessPersistentHandleStore('new');
			if ~isempty(name)
				g.Name = name;
			end
		end
		function g = getInstance(varargin)
			
			% todo duplicated input-checking in access function call!!!! fix!!
			if (nargin == 2)
				% MATCH PROPERTY-VALUE PAIR
				prop = varargin{1};
				val = varargin(2:end);
				
			elseif (nargin == 1)
				% DEFAULT PROPERTY TO MATCH IS 'NAME'
				prop = 'Name';
				val = varargin;
				
			else
				% IF PROPERTY TO MATCH AND/OR VALUE TO MATCH IS EMPTY -> REPLACE WITH EMPTY?? OR 'ALL'??
				prop = 'Name';
				val = {'all'};
				
			end
			
			args = [{prop} , val];
			g = accessPersistentHandleStore('get', args{:}); %prop, val{:});
			
			% OR
			% g = accessPersistentHandleStore('get', varargin{:});
			
		end
		function resetInstance(name)
			if (nargin<1), name='all'; end
			accessPersistentHandleStore('reset',name);
		end
		
	end
	
	% todo -> setCurrentInstance(name)
	% todo -> getInstance( propName, propVal)
	% todo -> find or make a generic version (or I already did??)
	% TODO: rather than multi-instance
	% -> create ReferenceNodes{ 'Root','TunableProps','Status','Control'}
	% as in Neo4j
	
	
end

function varargout = accessPersistentHandleStore(action,varargin)

% STORE HANDLES TO ALL INSTANCES IN PERSISTENT VARIABLES
persistent gCurrent gList
initGraphListIfNecessary();
if isempty(gCurrent), gCurrent = gList(end); end

% RETURN CURRENT, NAMED, ALL, OR NEW INSTANCE, or RESET PERSISTENT STORAGE
switch action
	case 'current'
		varargout{1} = gCurrent;
		
	case 'new'
		gList(end+1) = ign.core.graph.Graph();
		gCurrent = gList(end);
		if nargout, varargout{1} = gCurrent; end
		
	otherwise % case {'get','reset'} % todo 'set'
		% 		if (nargin<2)
		% 			name = {'all'};
		% 		else
		% 			name = varargin;
		% 		end
		
		% CHECK INPUT -> PROPERTY-VALUE PAIR FORMAT
		if (nargin<2)
			prop = 'Name';
			val = {'all'};
		else
			prop = varargin{1};
			val = varargin(2:end);
		end
		
		% MULTI-VALUE MAY BE IN CELL ARRAY (DEFAULT FORMAT FOR CLEANER CODE)
		if ~iscell(val), val = {val}; end
		
		% CYCLE THROUGH ALL VALUES TO MATCH
		k=1;
		propList = {gList.(prop)};
		propMatch = false(size(propList));
		while k <= numel(val)
			propMatch = propMatch | searchByPropVal(val{k}, propList);
			k = k + 1;
		end
		
		% USE LOGICAL VECTOR OF MATCHES TO SELECT FROM LIST TO RETURN OR DELETE
		switch action
			case 'get'
				varargout{1} = gList(propMatch);
			case'reset'
				if any(propMatch)
					delete(gList(propMatch));
					gList = gList(~propMatch);
					initGraphListIfNecessary();
					gCurrent = gList(end);
				end
				varargout{1} = gList;
		end
end

if nargout > 1
	varargout{2} = gList;
end

% SUBFUNCTION IMPLEMENTING WHAT IS AN ACCEPTABLE 'NAME' QUERY {'','all',strmatch}
	function match = searchByPropVal( q, V)
		if isstr(q) && iscellstr(V)
			match = searchByName( q, V);
		else
			try
				match = cellfun(@isequal, repmat(q,size(V)), V);
			catch
				match = false(size(V));
			end
		end
		% todo -> dig up the function for comparing struct fields and/or cells???
	end

	function match = searchByName( str, C)
		if isempty(str)
			% EMPTY STR RETURNS EMPTY LIST (OR GRAPHS WITH EMPTY NAME)
			match = ~cellfun(@isempty, C);
			
		elseif strcmpi(str,'all')
			% 'ALL' RETURNS ENTIRE LIST
			match = true(size(C));
		else
			
			% MATCH GIVEN NAME EXACTLY
			match = strcmp( str, C);
			
			% ACCEPT CASE-INSENSITIVE & TRUNCATED MATCHES IF EXACT MATCH FAILES
			if ~any(match)
				match = strncmpi( str, C, length(str));
			end
		end
	end
	function initGraphListIfNecessary()
		if isempty(gList)
			gList = ign.core.graph.Graph();
		end
	end
end






	
	%Name = 'DefaultGraph'
	% 	AdjacencyMatrix
	% 		IncidenceMatrix
	% GraphBase PID, Device?

% pg = physmod.gl.Graph
% osgmod = matlab.graphics.primitive.world.osg.ModelFile




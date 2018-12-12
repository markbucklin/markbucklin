function varargout = accessNamedCacheVariable(cacheName, variableName, variableValue)
% ACCESSNAMEDCACHEVARIABLE  Persistent storage of named variables in named caches in a map of maps 
%		>> var = accessNamedCacheVariable(cacheName, variableName)
%		>> accessNamedCacheVariable(cacheName, variableName, variableValue)
%		>> accessNamedCacheVariable(cacheName) % reset
% current benchmark -> roughly 120 micros

% INITIALIZE PERSISTENT TOP-LEVEL CACHE MAP
mlock;
persistent cacheStore;
cacheStore = ign.util.persistentMapVariable(cacheStore);


data = [];
if (nargin < 1)
	% RESET ALL CACHES
	cacheStore = containers.Map();
	
else
	% RETRIEVE NAMED CACHE FROM TOP-LEVEL MAP -> SUBFUNCTION
	cache = getNamedCache(cacheName);
	
	if (nargin < 3)
		% GET NAMED VARIABLE FROM NAMED CACHE
		if isKey(cache, variableName)
			data = cache(variableName);
		end
		
	else
		% SET NAMED VARIABLE IN NAMED CACHE		
		cache(variableName) = variableValue;
		
	end
	
end

% RETURN OUTPUT
if nargout
	varargout{1} = data;
	
end

% SUBFUNCTION -> RETRIEVE/INITIALIZE NAMED CACHE
	function C = getNamedCache(name)
		if isKey(cacheStore,name)
			C = cacheStore(name);
		else
			C = containers.Map;
			cacheStore(name) = C;
		end
	end

end




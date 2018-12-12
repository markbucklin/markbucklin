function pMap = persistentMapVariable(pMap)
% persistentMapVariable - Initialize persistent function variable as containers.Map
%
% Call to initialize a persistent function variable as an empty hash-map (type: containers.Map) or
% ensure prior initialization to the containers.Map type.
%
%	Usage:
%			... (in function) ...
%			persistent pMap;
%			pMap = ign.util.persistentMapVariable(pMap);
%			... (rest of function) ...
%

if isempty(pMap) && ~ismap(pMap)
	pMap = containers.Map();
end




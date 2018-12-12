function pFlag = persistentFlagVariable(pFlag, initFlagValue)
% persistentFlagVariable - Initialize persistent function variable as logical (false) flag
%
% Call to initialize a persistent function variable as an empty hash-map (type: containers.Map) or
% ensure prior initialization to the containers.Map type.
%
%	Usage:
%			... (in function) ...
%			persistent pFlag;
%			pFlag = ign.util.persistentFlagVariable(pFlag);
%					OR
%			pFlag = ign.util.persistentFlagVariable(pFlag, true);
%
%			... (rest of function) ...
%

if (nargin < 2)
	initFlagValue = false;
end

if isempty(pFlag) || ~islogical(pFlag)
	pFlag = initFlagValue;
end

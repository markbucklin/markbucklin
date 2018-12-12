function argInfo = getArgumentInfo()
% work in progress - utility function for quickly returning information
% about function input arguments


argInfo = struct(...
    'index',[],...
    'internalName',[],...
    'externalName',[],...
    'size',[],...
    'class',[],...
    'length',[],...
    'bytes',[]);
numIn = evalin('caller', 'nargin');
% [stackStruct, wkspInfo] = dbstack('-completenames');

for k = 1:numIn
    argInfo(k).index = k;
    name = evalin('caller', sprintf('inputname(%d)',k));
    if ~isempty(name)
        argInfo(k).externalName = name;
        s = whos(name);
    end
end
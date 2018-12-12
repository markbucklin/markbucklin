function constructorFcn = getClassConstructor( classInput )
% GETCLASSCONSTRUCTOR - Get function handle for null (blank) class constructor
%
% Usage:
%		-> Retrieve constructor for an object, or given class-name character string
%			>> nullConstructorFcn = getClassConstructor( classObj );
%			>> nullConstructorFcn = getClassConstructor( 'ClassName' );
%		-> Clear the persistent variable that caches constructors to speed retrieval
%			>> getClassConstructor()
%			>> getClassConstructor( [] )
%
% todo: perhaps name getClassConstructor instead?

% DECLARE & INITIALIZE CACHE (CONTAINERS.MAP)
persistent constructorCache
constructorCache = ignition.util.persistentMapVariable(constructorCache);

if nargin && ~isempty(classInput)
	% DETERMINE NAME FROM TYPE OF INPUT
	if isobject(classInput)
		% OBJECT (INSTANCE OF CLASS)
		className = class(classInput);
		
	elseif ischar(classInput)
		% CHARACTER ARRAY (CLASS-NAME)
		className = classInput;
		
	elseif iscell(classInput)
		% CELL ARRAY -> CALL RECURSIVELY
		constructorFcn = cellfun(@ignition.util.getClassConstructor,...
			classInput, 'UniformOutput',false);
		return
		
	else
		% UNKNOWN -> ERROR
		error('Ignition:GetClassConstructor:UnknownInput', ...
			'Unknown input type passed to ignition.util.getClassConstructor: %s',...
			class(classInput))
		
	end
	
	% GET FUNCTION-HANDLE FOR CONSTRUCTOR FROM CLASSNAME OR CACHED HANDLE	
	classKey = strrep(className,'.','_');		
	if isKey(constructorCache,classKey)
		% CACHE HIT -> RETRIEVE
		constructorFcn = constructorCache(classKey);
		
	else
		% CACHE MISS -> BUILD USING CLASS-NAME
		constructorFcn = str2func(className);
		constructorCache(classKey) = constructorFcn;
	end
		
else
	% CLEAR CACHE OF CONSTRUCTOR FUNCTIONS
	constructorCache = containers.Map();
	
end










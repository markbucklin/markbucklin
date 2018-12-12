function msgID = constructMessageIdentifier( src, msg )
% constructMessageIdentifier - Utility function to help construct a message identifier
%
% This utility function can be called to aid construction of a message identifier (message ID) such as can be used when throwing/handling errors and warnings

if isobject(src)
	% GET METACLASS OF CALLING OBJECT
	mobj = metaclass(src);
	
	% GET TOP PACKAGE
	srcPkg = mobj.ContainingPackage;
	pkg = srcPkg;
	while ~isempty(pkg.ContainingPackage)
		pkg = pkg.ContainingPackage;
	end
	parentPackageName = pkg.Name;
			
	% todo
			
			
else
	
	
	
end
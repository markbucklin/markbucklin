warning('getCurrentClassPackage.m being called from scrap directory: Z:\Files\MATLAB\toolbox\ignition\scrap')



className = evalin('caller', 'mfilename(''class'')');
classCallList = regexp(className, '(\w*)+.', 'tokens');

if numel(classCallList) > 1
	classParentPkgList = cat(2, classCallList{1:end-1});
	if numel(classParentPkgList) > 1
		currentClassPkg = [sprintf('%s.', classParentPkgList{1:end-1}), classParentPkgList{end}];		
	else
		currentClassPkg = classParentPkgList{1};
	end
	
else
	classParentPkgList = {};
	
end
	



% className = mfilename('class');


% classParentPkg = strsplit(className,'.');


% callerPath = evalin('caller', 'mfilename(''fullpath'')');
% fullPkgName = regexp(callerPath, '\+(\w)+', 'tokens');
% currentPkgName = sprintf('%s.', fullPkgName{1:end-1});


% parentPkgName = [ sprintf('%s.', fullPkgName{1:end-1}), '*'];
% import(parentPkgName)




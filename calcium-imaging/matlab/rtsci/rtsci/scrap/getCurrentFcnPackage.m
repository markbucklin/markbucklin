warning('getCurrentFcnPackage.m being called from scrap directory: Z:\Files\rtsci\rtsci\scrap')
% function currentPkgName = getCurrentPackage()
% NOT FUNCTIONAL: TODO



% className = mfilename('class');
% fullPkgName = strsplit(className,'.');



% callerPath = evalin('caller', 'mfilename(''fullpath'')');
% callerClass = evalin('caller', 'mfilename(''class'')');
% fullPkgName = regexp(callerPath, '\+(\w)+', 'tokens');
% fullPkgName = strsplit(className,'.');
% currentPkgName = sprintf('%s.', fullPkgName{1:end-1});



fcnPath = evalin('caller', 'mfilename(''function'')');
fcnCallList = regexp(fcnPath, '\+(\w*)+.', 'tokens');

if numel(fcnCallList) > 1
	fcnParentPkgList = cat(2, fcnCallList{1:end-1});
	if numel(fcnParentPkgList) > 1
		currentFcnPkg = [sprintf('%s.', fcnParentPkgList{1:end-1}), fcnParentPkgList{end}];		
	else
		currentFcnPkg = fcnParentPkgList{1};
	end
	
else
	fcnParentPkgList = {};
	
end








% callerPath = evalin('caller', 'mfilename(''fullpath'')');
% fullPkgName = regexp(callerPath, '\+(\w)+', 'tokens');
% currentPkgName = sprintf('%s.', fullPkgName{1:end-1});


% parentPkgName = [ sprintf('%s.', fullPkgName{1:end-1}), '*'];
% import(parentPkgName)




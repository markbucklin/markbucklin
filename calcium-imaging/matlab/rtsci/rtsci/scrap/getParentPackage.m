function parentPkgName = getParentPackage()
warning('getParentPackage.m being called from scrap directory: Z:\Files\rtsci\rtsci\scrap')


% className = mfilename('class');
% fullPkgName = strsplit(className,'.');

callerPath = evalin('caller', 'mfilename(''fullpath'')');
fullPkgName = regexp(callerPath, '\+(\w)+', 'tokens');
parentPkgName = sprintf('%s.', fullPkgName{1:end-1});


% parentPkgName = [ sprintf('%s.', fullPkgName{1:end-1}), '*'];
% import(parentPkgName)




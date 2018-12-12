warning('getCurrentPackage.m being called from scrap directory: Z:\Files\rtsci\rtsci\scrap')
% function currentPkgName = getCurrentPackage()
% NOT FUNCTIONAL: TODO



% className = mfilename('class');
% fullPkgName = strsplit(className,'.');



callerPath = evalin('caller', 'mfilename(''fullpath'')');
% callerClass = evalin('caller', 'mfilename(''class'')');
fullPkgName = regexp(callerPath, '\+(\w)+', 'tokens');
% fullPkgName = strsplit(className,'.');
currentPkgName = sprintf('%s.', fullPkgName{1:end-1});


% callerPath = evalin('caller', 'mfilename(''fullpath'')');
% fullPkgName = regexp(callerPath, '\+(\w)+', 'tokens');
% currentPkgName = sprintf('%s.', fullPkgName{1:end-1});


% parentPkgName = [ sprintf('%s.', fullPkgName{1:end-1}), '*'];
% import(parentPkgName)




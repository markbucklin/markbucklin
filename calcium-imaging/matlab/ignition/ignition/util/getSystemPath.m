function [sysPath, sysPathStr] = getSystemPath()
% >> [sysPath, sysPathStr] = getSystemPath()
% todo: add linux & mac




% 
% if ismac
% 	%todo
% 	error('todo')
% elseif isunix
% 	%todo
% 	error('todo')
% else	
% 	% WINDOWS
% 	[~,sysPathStr] = system('echo %PATH%');
% 	sysPath = strsplit(sysPathStr,';')';
% end


sysPathStr = getenv('PATH');
sysPath = strsplit(sysPathStr,';')';
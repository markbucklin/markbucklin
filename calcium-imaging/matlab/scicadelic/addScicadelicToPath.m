function varargout = addScicadelicToPath()

[thisFileDirectory,~,~] = fileparts(which(mfilename));

% todo, make generic for any toolbox

% THIS FILE MAY BE IN THE SAME FOLER AS SCICADELIC ROOT OR WITHIN THE SCICADELIC FOLDER
if isdir( [thisFileDirectory, filesep, 'scicadelic'])
	scicadelicRootDirectory = [thisFileDirectory, filesep, 'scicadelic'];
else
	scicadelicRootDirectory = thisFileDirectory;
end

% DEFINE PATHS TO ADD (ALTERNATIVELY USE GENPATH)
dirList = {scicadelicRootDirectory, ...
	[ scicadelicRootDirectory, filesep, 'Debugging Functions'] ,...
	[ scicadelicRootDirectory, filesep, 'Visualization'] ,...
	[ scicadelicRootDirectory, filesep, 'RegionOfInterest'] ,...
	[ scicadelicRootDirectory, filesep, 'GpuKernelFunctions'] };

% ADD TO PATH WHILE SAVING OLD PATH IN LOCAL MAT FILE
oldPath = addpath(dirList{:});
try
	pathCache = load('pathCache');
catch
	pathCache = containers.Map;
end
pathCache(datestr(now)) = oldPath; %#<ok>
save('Prior Path Cache', 'pathCache')
assignin('base','pathCache',pathCache)


savepath


if nargout
	pathCleanup = onCleanup( @() removeFromPath(dirList) );
	
	varargout{1} = pathCleanup;
	
end



end



function removeFromPath(dirList)
rmpath( dirList{:} )
savepath
end
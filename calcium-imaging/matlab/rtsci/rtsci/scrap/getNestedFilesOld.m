function filenameStructure = getNestedFilesOld(varargin)
warning('getNestedFilesOld.m being called from scrap directory: Z:\Files\rtsci\rtsci\scrap')
if nargin>0
	topDir = varargin{1};
else
	topDir = pwd;
end
dirInfo = dir(topDir);
[~,topDirName] = fileparts(topDir);
topDirFieldName = topDirName(isstrprop(topDirName, 'alphanum'));

% Extract Filenames
topLevelFiles = dirInfo(~[dirInfo.isdir]);
filenameStructure.nestedFiles = {topLevelFiles.name};
filenameStructure.topLevelFiles = {topLevelFiles.name};
filenameStructure.nestedPaths = {topDir};
% filenameStructure.(sprintf('Top_%s',topDirFieldName)) = {topFiles.name};

% Extract Sub-Directories Recursively
subDir = dirInfo([dirInfo.isdir]);
subDir = subDir( ~( ...
	strcmp({subDir.name},'.') ...
	| strcmp({subDir.name},'..')));
if ~isempty(subDir)
	for n  =1:numel(subDir)
		[~,subDirName] = fileparts(subDir(n).name);
		subDirPath = [topDir, filesep, subDirName];
		
		subDirFieldName = subDirName(isstrprop(subDirName, 'alphanum')); % 'graphic' , 'punct', 'lower', 'wspace' , 'upper'		
		fieldname = sprintf('%s_%s',topDirFieldName,subDirFieldName);
		filenameStructure.(fieldname) = getNestedFilesOld(subDirPath);
		filenameStructure.nestedFiles = cat(2,...
			filenameStructure.nestedFiles,...
			filenameStructure.(fieldname).nestedFiles);
		
		filenameStructure.levelPath = subDirPath;
		filenameStructure.nestedPaths = cat(2,...
			filenameStructure.nestedPaths,...
			filenameStructure.(fieldname).nestedPaths);
	end
end





% [flist, plist] = matlab.codetools.requiredFilesAndProducts

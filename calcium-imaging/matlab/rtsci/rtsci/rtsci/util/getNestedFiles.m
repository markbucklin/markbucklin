function filenameStructure = getNestedFiles(varargin)
import rtsci.util.*
if nargin>0
	topDir = varargin{1};
else
	topDir = pwd;
end
dirInfo = dir(topDir);
[~,topDirName] = fileparts(topDir);
topDirName = topDirName(isletter(topDirName) | isnumeric(topDirName));

% getLocalFilePath = @ (s) cellfun(@(m) sprintf('%s%s%s', topDir, filesep, m), s.m, 'UniformOutput', false);

% Extract Filenames
topFiles = dirInfo(~[dirInfo.isdir]);
topFileNames = {topFiles.name};
filenameStructure.topFiles = topFileNames;
filenameStructure.allFileNames = topFileNames;
filenameStructure.allFilePaths = cellfun(@(m) sprintf('%s%s%s', topDir, filesep, m), topFileNames, 'UniformOutput', false);
filenameStructure.(sprintf('Top_%s',topDirName)) = {topFiles.name};

% Extract Sub-Directories Recursively
subDir = dirInfo([dirInfo.isdir]);
subDir = subDir( ~( ...
	strcmp({subDir.name},'.') ...
	| strcmp({subDir.name},'..')));
if ~isempty(subDir)
	for n  =1:numel(subDir)
		[~,subDirName] = fileparts(subDir(n).name);
		subDirName = subDirName(isletter(subDirName) | isnumeric(subDirName));
		fieldname = sprintf('%s_%s',topDirName,subDirName);
		
		fullDirPath = [topDir,filesep,subDir(n).name];
		filenameStructure.(fieldname) = getNestedFiles(fullDirPath);
		
		filenameStructure.allFileNames = cat(2,...
			filenameStructure.allFileNames,...
			filenameStructure.(fieldname).allFileNames);
		
		filenameStructure.allFilePaths = cat(2,...
			filenameStructure.allFilePaths,...
			filenameStructure.(fieldname).allFilePaths);
	end
end



% alternative: TODO

% curDir = pwd;
% 
% getLocalFilePath = @ (s) cellfun(@(m) sprintf('%s%s%s', curDir, filesep, m), s.m, 'UniformOutput', false);
% getLocalPackagePath = @ (s) cellfun(@(p) sprintf('%s%s+%s', curDir, filesep, p), s.packages, 'UniformOutput', false);
% 
% whatCurDir = what(curDir);
% 
% localFile = getLocalFilePath(whatCurDir);
% localPkg = getLocalPackagePath(whatCurDir);

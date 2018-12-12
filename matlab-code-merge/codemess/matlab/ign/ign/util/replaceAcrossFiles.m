function oldNewMap = replaceAcrossFiles(varargin)
% >> replaceAcrossFiles()
% >> oldNewMap = replaceAcrossFiles();
% >> oldNewMap = replaceAcrossFiles( oldNewMap);
% >> oldNewMap = replaceAcrossFiles('oldFcnName','newFcnName');

% INITIALIZE VARIABLES
str = {};
useCasePreserve = true;
oldNewMap = containers.Map;

% CHOOSE TOP DIRECTORY -> QUERY USER
startdir = pwd;
projectDirectory = uigetdir(startdir,'Set Directory');
options.WindowStyle = 'normal';

% GET FULL PATHS TO ALL FILES RECURSIVELY UNDER CHOSEN DIRECTORY
fs = getNestedFiles(projectDirectory);
allFiles = fs.allFilePaths;

% PERFORM REPLACEMENTS DEPENDING ON INPUT
switch nargin
	case 0 % replaceAcrossFiles()
		
		% CALL SUBFUNCTION TO QUERY USER FOR REPEAT TEXT REPLACEMENTS
		queryTextReplacement()
		
	case 1 % replaceAcrossFiles(oldNewMap)
		oldNewMap = varargin{1};
		allOldStr = oldNewMap.keys;
		for k=1:numel(allOldStr)
			oldStr = allOldStr{k};
			newStr = oldNewMap(oldStr);
			replaceOldWithNew(oldStr,newStr);
		end
		
	case 2 % replaceAcrossFiles(oldWord, newWord)
		oldStr = varargin{1};
		newStr = varargin{2};
		replaceOldWithNew(oldStr,newStr);
		
end

	function queryTextReplacement()
		
		% ASK USER FOR STRING REPLACEMENT PAIR
		str = inputdlg({'Find','Replace With'},'Find and Replace',1,{'',''},options);
		useCasePreserve = strcmp(questdlg('Preserve Case?'),'Yes');
		
		% MAKE REPLACEMENT IN EACH FILE
		repeatmode = true;
		while ~isempty(str)
			% CALL SUBFUNCTION TO REPLACE OLD WITH NEW
			replaceOldWithNew(str{1},str{2})
			
			% REPEAT QUERY UNTIL USER CANCELS OR CLOSES WINDOW
			if repeatmode
				str = inputdlg({'Find','Replace With'});
			else
				str = {};
			end
		end
		
		% SAVE HASH-MAP OF REPLACEMENTS
		prevReplacement = fullfile(projectDirectory,'text_replacement_map.mat');
		if exist(prevReplacement) == 2
			save(prevReplacement,'oldNewMap','-append');
		else
			save(prevReplacement,'oldNewMap');
		end
		
	end
	function replaceOldWithNew(oldWord,newWord)
		oldNewMap(oldWord) = newWord;
		fprintf('Replacing text:\t%s\t->\t%s\n', oldWord, newWord )
		for n = 1:length(allFiles);
			replaceIfMatch( allFiles{n}, oldWord, newWord)
		end
	end
	function replaceIfMatch( filePath, oldWord, newWord)
		% OPEN FILE & READ CURRENT TEXT
		fid = fopen(filePath);
		txt = textscan(fid,'%s','delimiter','\n','whitespace','');
		%txt = matlab.internal.getcode.mfile(afile);
		% strsplit(matlab.internal.getcode.mfile(afile),'\r\n')'
		fclose(fid);
		txt = txt{1};
		
		% CHECK FOR ANY MATCHES AND IN FILE TEXT
		lineHasMatch = ~cellfun(@isempty, strfind(txt, oldWord));
		if any( lineHasMatch)
			fprintf('\t%d matching lines in %s\n', nnz(lineHasMatch), filePath)
			if useCasePreserve
				txt = regexprep(txt,['\<',oldWord,'\>'],newWord,'warnings','preservecase');
			else
				txt = regexprep(txt,['\<',oldWord,'\>'],newWord,'warnings');
			end
			
			fid = fopen(filePath,'w+');
			try
				fprintf(fid,'%s\n',txt{:});
				fclose(fid);
			catch me
				getReport(me)
			end
		end
	end
end



function filenameStructure = getNestedFiles(varargin)
% import ign.util.*
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
end








% % NEW: can use internal fcn >> tmp = matlab.internal.getCode('findCorrPeakSubpixelOffset.m')

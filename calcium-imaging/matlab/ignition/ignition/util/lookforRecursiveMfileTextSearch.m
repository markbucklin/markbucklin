function fileSearch = lookforRecursiveMfileTextSearch()

import ignition.util.*

% CHOOSE TOP DIRECTORY
% if isdir('Z:\Files')
% 	startdir = 'Z:\Files';
% else
startdir = pwd;
% end
projectDirectory = uigetdir(startdir,'Set Directory');
options.WindowStyle = 'normal';

% ASK USER FOR STRING REPLACEMENT PAIR
str = inputdlg({'Look for'},'Look for string',1,{''},options);

% GET FULL PATHS TO ALL FILES RECURSIVELY UNDER CHOSEN DIRECTORY
[~, allFiles] = getNestedFiles(projectDirectory);

% MAKE REPLACEMENT IN EACH FILE
repeatmode = true;

numSearch = 1;

% hwait = waitbar(0,'SCANNING: ');

while ~isempty(str)
	wrd = ['\<',str{1},'\>'];
			
	fhit = runSearch(wrd, allFiles);
	% ffut(numSearch) = parfeval(@runSearch, 1, {wrd, allFiles}); %TODO
	
	fileSearch(numSearch).searchWord = wrd;
	fileSearch(numSearch).fileHits = fhit;
	
	
	if repeatmode
		str = inputdlg({'Look for'},'Look for string',1,{''},options);
		numSearch = numSearch + 1;
	else
		str = {};
	end
end
% delete(hwait)

end





function fileHits = runSearch(searchWord, allFiles)

N = numel(allFiles);
fileHits = struct.empty;
numFileHits = 0;
numLineHits = 0;

for n = 1:N;
	afile = allFiles{n};
	% 		[~,fname,fext] = fileparts(afile);
	
	% OPEN FILE & READ CURRENT TEXT
	fid = fopen(afile);
	txt = textscan(fid,'%s','delimiter','\n','whitespace','');
	fclose(fid);
	txt = txt{1};
	
	
	lineHit = ~cellfun(@isempty, regexp(txt, searchWord));
	if any(lineHit)
		numFileHits = numFileHits + 1;
		numLineHits = numLineHits + nnz(lineHit);
		fileHits(numFileHits).filepath = afile;
		fileHits(numFileHits).linenum = find(lineHit);
	end
	% 		waitbar(n/N, hwait, sprintf('SCANNING: %s%s', fname, fext))
	
end

end

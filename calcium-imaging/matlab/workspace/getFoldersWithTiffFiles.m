function foldersWithTiffs = getFoldersWithTiffFiles(startDir)
% Recursively Search for folders containing Tiff Files
% todo generalize for any file-type or search pattern
% Mark and Susie

if nargin<1
	startDir = pwd;
end


dir2Search = {startDir};
foldersWithTiffs = {};

while ~isempty(dir2Search)
	searchNextFolder()	
end
disp(foldersWithTiffs)

function searchNextFolder()
nextFolder = dir2Search{1};
d = dir(nextFolder);
if length(d)>2
	% Split current folder contents into Files and Folders
	dirContents = d(3:end);
	dirSubfolders = dirContents([dirContents.isdir]);
	dirFiles = dirContents(~[dirContents.isdir]);
	
	% Check if there are Tiffs in the Current Folder
	tiffFileMatch = ~cellfun( @isempty, regexp( {dirFiles.name}, '.tif$'));
	if any(tiffFileMatch)
		foldersWithTiffs{end+1} = nextFolder;
	end
	% 	tiffFiles = dirFiles(tiffFileMatch);
	
	
	% Add Sub-Folders from Folder Current to Recursive Search Queue
	dir2Search = [dir2Search ,...
		cellfun(@fullfile, {dirSubfolders.folder} , {dirSubfolders.name},...
		'UniformOutput', false)];
	
	
end
dir2Search(1) = [];
end


end
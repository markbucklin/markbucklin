function fullFilePath = selectTiffFiles(fdir)
% Returns a full file path or cell array of full file paths to TIFF files. Files are selected either
% by querying the user to choose files, or (if a valid directory string is given as input) by
% selecting all TIFF files from inside the given directory.
%
%			>> fullFileName = selectTiffFiles();
%			>> fullFileName = selectTiffFiles(pwd);
%			>> fullFileName = selectTiffFiles('Z:\Data\MyTiffFolder\');
%
% Mark Bucklin
% 02/2016
%

if (nargin < 1), fdir = []; end
if isempty(fdir) || ~isdir(fdir)
	% QUERY USER TO SELECT TIFF FILES
	[fname,fdir] = uigetfile('*.tif','MultiSelect','on');	
	
else
	% GET TIFF FILES FROM GIVEN DIRECTORY
	tiffInDir = dir(fullfile(fdir, '*.tif'));
	fname = {tiffInDir.name};
	
end

fullFilePath = updateFullFilePathFromNameDir(fname,fdir);
fullFilePath = fullFilePath(:);

end



function fullFilePath = updateFullFilePathFromNameDir(fname,fdir)
switch class(fname)
	case 'char'
		fullFilePath{1} = [fdir,fname];
	case 'cell'
		for n = numel(fname):-1:1
			% 						obj.FullFilePath{n} = [fdir,fname{n}];
			fullFilePath{n} = fullfile(fdir,fname{n});
		end
end
end

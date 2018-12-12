function config = configureTiffFileStream(tiffFileInput, parseFrameInfoFcn)
% configureTiffFileStream - File & file-type specific configuration


ignition.io.tiff.suppressTiffWarnings()
defaultParseFcn = @ignition.io.tiff.parseHamamatsuTiffTag; %todo -> separate folder, wrapper class


% ----------------------------------------------
% MANAGE INPUT -> FILENAMES OR TIFF HANDLES
% ----------------------------------------------
% EMPTY INPUT -> ASSIGN DEFAULTS
if (nargin < 2)
	%	CURRENT DEFAULT IS FOR HAMAMATSU (TODO)
	parseFrameInfoFcn = [];
	if (nargin < 1)
		tiffFileInput = [];
	end
end
if isempty(tiffFileInput)
	% QUERY USER FOR CELL ARRAY OF FILE NAMES
	tiffFileInput = ignition.io.FileWrapper('FileExtension','tif');
	fileInputObj = tiffFileInput;
else
	fileInputObj = ignition.io.FileWrapper.empty();
end
if isempty(parseFrameInfoFcn)
	parseFrameInfoFcn = defaultParseFcn;
end


% ----------------------------------------------
% CHECK INPUT: TIFF-HANDLES OR FILE-NAMES
% ----------------------------------------------
if isa(tiffFileInput, 'Tiff')
	% ARRAY OF TIFF-HANDLES
	allTiffObj = tiffFileInput;
	fullFilePath = {allTiffObj.FileName}';
	numFiles = numel(allTiffObj);
	
elseif iscell(tiffFileInput)
	% FILE-NAMES: MULTI-FILE
	fullFilePath = tiffFileInput;
	numFiles = numel(fullFilePath);
	
elseif ischar(tiffFileInput)
	% FILE-NAME: SINGLE
	fullFilePath = {tiffFileInput};
	numFiles = 1;
	
elseif isa(tiffFileInput, 'ignition.io.FileWrapper')
	% FILE-WRAPPER CLASS OBJECT
	fullFilePath = tiffFileInput.FullFilePath;
	numFiles = tiffFileInput.NumFiles;
	
end

% CREATE OR INCLUDE A TIFF-FILE-INPUT WRAPPER HANDLE
if isempty(fileInputObj)
	[fdir, ~ , fext] = fileparts(fullFilePath{1});
	for k=1:numel(fullFilePath)
		[~,fname{k},~] = fileparts(fullFilePath{k});
	end
	fileInputObj = ignition.io.FileWrapper(...
		'FileName', fname,...
		'FileDirectory', fdir,...
		'FileExtension',fext);
	% 	fileInputObj = ignition.io.FileWrapper('FullFilePath',fullFilePath);
end

% ADD TO CONFIGURATION STRUCTURE -> RETURN
config.fullFilePath = fullFilePath;
config.numFiles = numFiles;
config.fileInputObj = fileInputObj;
config.parseFrameInfoFcn = parseFrameInfoFcn;
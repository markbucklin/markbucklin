function [stackInfo, fileInfo] = initializeParallelTiffStackLoaderWorkers(fileNameInput,parseFrameInfoFcn)
%
%
%		parseFrameInfoFcn
%				function handle that takes a Tiff object as input and returns 'frameTime'
%				and 'frameInfo'
%
%

% parWorkerConst = initializeParallelTiffStackLoaderWorkers(fileNameInput,parseFrameInfoFcn)


% DEFAULT OUTPUT
parWorkerConst = [];

% SINGLE OR MULTI-FILE-INPUT
if iscell(fileNameInput)
	stackInfo.allFileNames = fileNameInput;
	numFiles = numel(stackInfo.allFileNames);
	
elseif ischar(fileNameInput)
	stackInfo.allFileNames = {fileNameInput};
	numFiles = 1;
	
end

% BLACK FILE-INFO STRUCTURE ARRAY
fileInfo = struct(...
	'fileName',stackInfo.allFileNames(:),...
	'numFrames',repmat({0},numFiles,1),...
	'firstIdx',repmat({[NaN]},numFiles,1),...
	'lastIdx',repmat({[NaN]},numFiles,1));

% CREATE CLIENT-SIDE TIFF OBJECTS
suppressTiffWarnings()
for kFile = 1:numFiles
	allTiffObj(kFile) = Tiff(stackInfo.allFileNames{kFile}, 'r');
end


% ----------------------------------------------
% STACK-INFO STRUCTURE
% ----------------------------------------------
stackInfo.tiffObj = allTiffObj;

% DETERMINE READABLE TIFF-TAGS
firstTiffObj = allTiffObj(1);
allTiffTagIDs = Tiff.TagID;
tagFieldNames = fields(allTiffTagIDs);
numTagFields = numel(tagFieldNames);
isTagReadable = true(numTagFields,1);
for tagIdx = 1:numTagFields
	try
		tagName = tagFieldNames{tagIdx};
		tagID = allTiffTagIDs.(tagName);
		readableTiffTags.(tagName) = firstTiffObj.getTag( tagID );
		readableTagIDs.(tagName) = tagID;
	catch me
		isTagReadable(tagIdx) = false;
	end
end
readableTagFields = tagFieldNames(isTagReadable);
numReadableTagFields = sum(isTagReadable);
stackInfo.tagNames = readableTagFields;
stackInfo.tagIDs = readableTagIDs;
stackInfo.firstFrameTag = readableTiffTags;


% RECORD FIRST FRAME TIME & INFO (FRAME-METADATA)
[frameTime, frameInfo] = parseFrameInfoFcn(firstTiffObj);
stackInfo.firstFrameTime = frameTime;
stackInfo.firstFrameInfo = frameInfo;



% ----------------------------------------------
% FILE-INFO STRUCTURE
% ----------------------------------------------
for kFile = 1:numFiles
	fileInfo(kFile).fileName = stackInfo.allFileNames{kFile};
	tiffObj = allTiffObj(kFile);
	
	% RECORD FIRST FRAME TIME & INFO (FRAME-METADATA)
	[frameTime, frameInfo] = parseFrameInfoFcn(tiffObj);
	fileInfo(kFile).firstFrameTime = frameTime;
	fileInfo(kFile).firstFrameInfo = frameInfo;
	
	% GET NUMBER OF FRAMES IN CURRENT FILE
	frameCounter = currentDirectory(tiffObj);
	countIncrement = 64;
	while ~lastDirectory(tiffObj)
		stridedFrameCounter = frameCounter + countIncrement;
		try
			setDirectory(tiffObj, stridedFrameCounter);
			frameCounter = stridedFrameCounter;
		catch
			countIncrement = max(1, floor(countIncrement/2));
		end
	end
	fileInfo(kFile).numFrames = currentDirectory(tiffObj);
	
	% GET LAST FRAME-TIME & FRAME-INFO
	setDirectory(tiffObj, fileInfo(kFile).numFrames); % ensure last: bug workaround
	[frameTime, frameInfo] = parseFrameInfoFcn(tiffObj);
	fileInfo(kFile).lastFrameTime = frameTime;
	fileInfo(kFile).lastFrameInfo = frameInfo;
	
	% CHECK IF THIS IS THE LAST TIFF FILE
	if (kFile == numFiles)
		for rtIdx = 1:numReadableTagFields
			rtagName = readableTagFields{rtIdx};
			rtagID = readableTagIDs.(rtagName);
			rtagVal.(rtagName) = tiffObj.getTag(rtagID);
		end
		stackInfo.lastFrameTag = rtagVal;
		stackInfo.lastFrameTime = frameTime;
		stackInfo.lastFrameInfo = frameInfo;
	end
	
	
	% RESET DIRECTORY OR CLOSE FILE DOWN
	setDirectory(tiffObj, 1);
	% close tiffObj if parallel
	
end

% GET FRAME DIMENSIONS
numCols = readableTiffTags.ImageWidth;
numRows = readableTiffTags.ImageLength;
numChannels = readableTiffTags.ImageDepth;
frameSize = [numRows, numCols numChannels];

% & BIT-DEPTH & MEGA-BYTES PER FRAME
numBitsPerPixel = readableTiffTags.BitsPerSample;
bytesPerPixel = ceil(numBitsPerPixel/8);
bytesPerFrame = numRows * numCols * numChannels * bytesPerPixel;
stackInfo.megaBytesPerFrame = bytesPerFrame / (2^20);

% SET DATATYPE STRING
switch numBitsPerPixel
	case 16
		stackInfo.returnedDataType = 'uint16';
	case 8
		stackInfo.returnedDataType = 'uint8';
	otherwise
		stackInfo.returnedDataType = 'single';
end

% GET FIRST & LAST FRAME IDX FOR EACH FILE
numFramesTotal = sum([fileInfo(:).numFrames]);
lastFrameIdx = cumsum([fileInfo(:).numFrames]);
fileFrameIdx.first = [0 lastFrameIdx(1:end-1)]+1;
fileFrameIdx.last = lastFrameIdx;
for kFile = 1:numFiles
	fileInfo(kFile).firstIdx = fileFrameIdx.first(kFile);
	fileInfo(kFile).lastIdx = fileFrameIdx.last(kFile);
end


stackInfo.numFrames = numFramesTotal;
stackInfo.frameSize = frameSize;
stackInfo.numCols = numCols;
stackInfo.numRows = numRows;
stackInfo.numChannels = numChannels;



% ============================================================
% NEW
% ============================================================

% CONSTRUCT FRAME-IDX -> FILE-IDX MAP (LUT)
frame2FileIdxMap = zeros(numFramesTotal, 1,'uint32');
frameIdx = (1:numFramesTotal)';
for kFile = 1:numFiles
	firstIdx = fileInfo(kFile).firstIdx;
	lastIdx = fileInfo(kFile).lastIdx;
	hasIdx = (frameIdx >= firstIdx) & (frameIdx <= lastIdx);
	frame2FileIdxMap(hasIdx) = kFile;
end

stackInfo.frame2FileIdxMap = frame2FileIdxMap;


% CLOSE CLIENT TIFF OBJECTS
for kFile = 1:numel(allTiffObj)
	close(allTiffObj(kFile));
end

end






function suppressTiffWarnings()

warning('off','MATLAB:imagesci:tiffmexutils:libtiffWarning')
warning('off','MATLAB:tifflib:TIFFReadDirectory:libraryWarning')

end














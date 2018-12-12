function [stackInfo, fileInfo, allTiffObj] = initializeTiffStack(tiffFileInput, parseFrameInfoFcn)
%
%
%		parseFrameInfoFcn
%				function handle that takes a Tiff object as input and returns 'frameTime'
%				and 'frameInfo'
%
%
% VIDEO-INPUT COMPATIBLE FRAME INFO (metadata)
% frameInfo.AbsTime = [];
% frameInfo.FrameNumber = [];		-> frameIdx relative to start of stack
% frameInfo.RelativeFrame = []; -> frameIdx relative to start of file
% frameInfo.TriggerIndex = [];	-> fileIdx as ordered in stack of Tiff files
%
%			>> [stackInfo, fileInfo, tiffObj] = initializeTiffStack( fileNameInput , @parseHamamatsuTiffTag )
%			>> [stackInfo, fileInfo, tiffObj] = initializeTiffStack( selectTiffFiles() , @parseHamamatsuTiffTag )


defaultParseFcn = @parseHamamatsuTiffTag;  %todo

% ----------------------------------------------
% MANAGE INPUT -> FILENAMES OR TIFF HANDLES
% ----------------------------------------------
% EMPTY INPUT -> ASSIGN DEFAULTS
if (nargin < 2)
	%	CURRENT DEFAULT IS FOR HAMAMATSU (TODO)
	parseFrameInfoFcn = defaultParseFcn;
	if (nargin < 1)
		tiffFileInput = [];
	end
end
if isempty(tiffFileInput)
	% QUERY USER FOR CELL ARRAY OF FILE NAMES
	tiffFileInput = selectTiffFiles();
end


% ----------------------------------------------
% CHECK INPUT: TIFF-HANDLES OR FILE-NAMES
% ----------------------------------------------
if isa(tiffFileInput, 'Tiff')
	% ARRAY OF TIFF-HANDLES
	allTiffObj = tiffFileInput;
	fullFilePath = {allTiffObj.FileName}';
	numFiles = numel(allTiffObj);
	
else
	% FILE-NAME(S): DETERMINE SINGLE OR MULTI-FILE
	if iscell(tiffFileInput)
		fullFilePath = tiffFileInput;
		numFiles = numel(fullFilePath);		
	elseif ischar(tiffFileInput)
		fullFilePath = {tiffFileInput};
		numFiles = 1;		
	else
		% error
	end
	
	% CREATE CLIENT-SIDE TIFF OBJECTS
	suppressTiffWarnings()
	for kFile = 1:numFiles
		allTiffObj(kFile) = Tiff(fullFilePath{kFile}, 'r');
		addlistener(allTiffObj(kFile), 'ObjectBeingDestroyed', @(src,~) close(src));
	end
	
end

% ADD TO STACK INFO
stackInfo.fullFilePath = fullFilePath;
stackInfo.numFiles = numFiles;




% ----------------------------------------------
% DETERMINE READABLE TIFF-TAGS
% ----------------------------------------------
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
	catch
		isTagReadable(tagIdx) = false;		
	end
end
readableTagFields = tagFieldNames(isTagReadable);
numReadableTagFields = sum(isTagReadable);

% ADD TO STACK INFO
stackInfo.tagNames = readableTagFields;
stackInfo.tagIDs = readableTagIDs;
stackInfo.firstFrameTag = readableTiffTags;


% ----------------------------------------------
% RECORD FIRST FRAME TIME & INFO (FRAME-METADATA)
% ----------------------------------------------
[frameTime, frameInfo] = parseFrameInfoFcn(firstTiffObj);

% ADD TO STACK INFO
stackInfo.firstFrameTime = frameTime;
stackInfo.firstFrameInfo = frameInfo;



% ----------------------------------------------
% FILE-INFO STRUCTURE
% ----------------------------------------------
lastFileNumFrames = nan; %new
for kFile = 1:numFiles
	fileInfo(kFile).fullFilePath = stackInfo.fullFilePath{kFile};
	tiffObj = allTiffObj(kFile);
	
	% RECORD FIRST FRAME TIME & INFO (FRAME-METADATA)
	[frameTime, frameInfo] = parseFrameInfoFcn(tiffObj);
	fileInfo(kFile).firstFrameTime = frameTime;
	fileInfo(kFile).firstFrameInfo = frameInfo;
	
	% GET NUMBER OF FRAMES IN CURRENT FILE
	frameCounter = currentDirectory(tiffObj);
	if isnan(lastFileNumFrames) %new
		countIncrement = 64;
	else
		countIncrement = lastFileNumFrames-1;
	end
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
	lastFileNumFrames = currentDirectory(tiffObj);
	
	% GET LAST FRAME-TIME & FRAME-INFO
	setDirectory(tiffObj, fileInfo(kFile).numFrames); % ensure last: bug workaround
	[frameTime, frameInfo] = parseFrameInfoFcn(tiffObj);
	fileInfo(kFile).lastFrameTime = frameTime;
	fileInfo(kFile).lastFrameInfo = frameInfo;
	
	% GET LAST FRAME-INFO FROM LAST TIFF FILE	
	if (kFile == numFiles)
		lastTiffObj = tiffObj;
		for rtIdx = 1:numReadableTagFields
			rtagName = readableTagFields{rtIdx};
			rtagID = readableTagIDs.(rtagName);
			rtagVal.(rtagName) = lastTiffObj.getTag(rtagID);
		end
		
		% ADD TO STACK INFO
		stackInfo.lastFrameTag = rtagVal;
		stackInfo.lastFrameTime = frameTime;
		stackInfo.lastFrameInfo = frameInfo;
	end
	
	% RESET DIRECTORY OR CLOSE FILE DOWN
	setDirectory(tiffObj, 1);
	
end

% GET FRAME DIMENSIONS
numCols = readableTiffTags.ImageWidth;
numRows = readableTiffTags.ImageLength;
numChannels = readableTiffTags.ImageDepth;
frameSize = [numRows, numCols numChannels];

% BIT-DEPTH & MEGA-BYTES PER FRAME
numBitsPerPixel = readableTiffTags.BitsPerSample;
bytesPerPixel = ceil(numBitsPerPixel/8);
bytesPerFrame = numRows * numCols * numChannels * bytesPerPixel;
stackInfo.megaBytesPerFrame = bytesPerFrame / (2^20);
stackInfo.bytesPerPixel = bytesPerPixel;

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

% ADD TO STACK INFO
stackInfo.numFrames = numFramesTotal;
stackInfo.frameSize = frameSize;
stackInfo.numCols = numCols;
stackInfo.numRows = numRows;
stackInfo.numChannels = numChannels;



% ============================================================
% FRAME-TO-FILE IDX LOOKUP-TABLE
% ============================================================

% CONSTRUCT FRAME-IDX -> FILE-IDX MAP (LUT)
fileIdxLUT = zeros(numFramesTotal, 1,'double'); % was uint32
relativeFrameIdxLUT = zeros(numFramesTotal, 1,'double');
frameIdx = (1:numFramesTotal)';
lastFrameIdx = 0;
for kFile = 1:numFiles
	
	% INCREMENT FIRST FRAME IDX USING PREVIOUS LAST FRAME IDX
	numFileFrames = fileInfo(kFile).numFrames;
	firstFrameIdx = lastFrameIdx + 1;
	lastFrameIdx = lastFrameIdx + numFileFrames;
	
	% CONTINUE UPDATING FILE-INFO STRUCTURE
	fileInfo(kFile).firstFrameIdx = firstFrameIdx;
	fileInfo(kFile).lastFrameIdx = lastFrameIdx;
	
	% FILL LOOKUP-TABLES THAT MAP FRAME-INDEX -> LOCALFRAMEIDX OR FILEIDX
	hasIdx = (frameIdx >= firstFrameIdx) & (frameIdx <= lastFrameIdx);	
	fileIdxLUT(hasIdx) = kFile;
	% 	numFileFrames = nnz(hasIdx);
	relativeFrameIdxLUT(hasIdx) = uint32(1:numFileFrames)';
end

% CONSTRUCT & STORE FUNCTION-HANDLES FOR LUT ACCESS
[stackInfo.isValidIdx, stackInfo.getValidIdx, stackInfo.lookupFileIdx, stackInfo.lookupRelIdx] = ...
	initializeIdxLookupFcn( numFramesTotal, fileIdxLUT, relativeFrameIdxLUT);

% ADD RAW LUTs TO STACK INFO
% stackInfo.fileIdxLUT = fileIdxLUT;
% stackInfo.relativeFrameIdxLUT = relativeFrameIdxLUT;

% STORE THE FRAME-INFO PARSING FUNCTION
stackInfo.parseFrameInfoFcn = parseFrameInfoFcn;


end




function [isValidIdx, getValidIdx, lookFileIdx, lookRelativeIdx] = initializeIdxLookupFcn( lastidx, fileidxlut, relframeidxlut)
% CONSTRUCT FUNCTION HANDLES FOR MAPPING INDICES
isValidIdx = @(idx) bsxfun(@and, (idx>=1) , (idx<=lastidx)) ;
getValidIdx = @(idx) idx( isValidIdx(idx)) ;
lookFileIdx = @(idx) fileidxlut( getValidIdx(idx)) ;
lookRelativeIdx = @(idx) relframeidxlut(getValidIdx(idx)) ;

end



function suppressTiffWarnings()

% SUPPRESS TIFFLIB WARNINGS
warning('off','MATLAB:imagesci:tiffmexutils:libtiffWarning')
warning('off','MATLAB:tifflib:TIFFReadDirectory:libraryWarning')
warning('off','MATLAB:imagesci:Tiff:closingFileHandle')

end














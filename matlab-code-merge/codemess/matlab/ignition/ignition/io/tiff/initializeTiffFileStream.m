function [config,control,state] = initializeTiffFileStream(config)
% >> stack = initializeTiffFileStream(config)
% Initializes a structure of cached/persistent task data that will be used by to read and parse the
% Tiff files specified by the input Configuration. Also, will contain State variables to indicate
% which frames have been read, and the next sequence of frames to read, as well as lower and upper
% limits (first/last indices) indicating when to stop reading if the readTiffFileStream function is
% called in a loop.

try
	
	if nargin < 1
		config = struct.empty();
	end
	if isempty(config)
		config = ignition.io.tiff.configureTiffFileStream();
	end
	
	% RETRIEVE VARIABLES FROM CONFIGURATION FUNCTION
	fullFilePath = config.fullFilePath;
	numFiles = config.numFiles;
	parseFrameInfoFcn = config.parseFrameInfoFcn;
	
	% CREATE CLIENT-SIDE TIFF OBJECTS
	ignition.io.tiff.suppressTiffWarnings()
	for kFile = 1:numFiles
		allTiffObj(kFile) = Tiff(fullFilePath{kFile}, 'r');
		addlistener(allTiffObj(kFile), 'ObjectBeingDestroyed', @(src,~) close(src));
	end
	
	
	
	% ----------------------------------------------
	%% DETERMINE READABLE TIFF-TAGS
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
	config.tagNames = readableTagFields;
	config.tagIDs = readableTagIDs; % 4KB
	config.firstFrameTag = readableTiffTags; % 9KB
	
	
	% ----------------------------------------------
	%% RECORD FIRST FRAME TIME & INFO (FRAME-METADATA)
	% ----------------------------------------------
	[frameTime, frameInfo] = parseFrameInfoFcn(firstTiffObj);
	
	% ADD TO STACK INFO
	config.firstFrameTime = frameTime;
	config.firstFrameInfo = frameInfo;
	
	
	
	% ----------------------------------------------
	%% FILE-INFO STRUCTURE
	% ----------------------------------------------
	lastFileNumFrames = nan; %new
	for kFile = 1:numFiles
		fileInfo(kFile).fullFilePath = config.fullFilePath{kFile};
		tiffObj = allTiffObj(kFile);
		
		% RECORD FIRST FRAME TIME & INFO (FRAME-METADATA)
		[frameTime, frameInfo] = parseFrameInfoFcn(tiffObj);
		fileInfo(kFile).firstFrameTime = frameTime;
		fileInfo(kFile).firstFrameInfo = frameInfo;
		
		% GET NUMBER OF FRAMES IN CURRENT FILE
		frameCounter = currentDirectory(tiffObj);
		if isnan(lastFileNumFrames) %new
			countIncrement = 2046;
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
			config.lastFrameTag = rtagVal; % 9KB
			config.lastFrameTime = frameTime;
			config.lastFrameInfo = frameInfo;
		end
		
		% RESET DIRECTORY OR CLOSE FILE DOWN
		setDirectory(tiffObj, 1);
		
	end
	
	% GET FRAME DIMENSIONS
	numCols = readableTiffTags.ImageWidth;
	numRows = readableTiffTags.ImageLength;
	numChannels = readableTiffTags.ImageDepth;
	frameSize = [numRows, numCols, numChannels];
	
	% BIT-DEPTH & MEGA-BYTES PER FRAME
	numBitsPerPixel = readableTiffTags.BitsPerSample;
	bytesPerPixel = ceil(numBitsPerPixel/8);
	bytesPerFrame = numRows * numCols * numChannels * bytesPerPixel;
	config.megaBytesPerFrame = bytesPerFrame / (2^20);
	config.bytesPerPixel = bytesPerPixel;
	
	% SET DATATYPE STRING
	switch numBitsPerPixel
		case 16
			config.returnedDataType = 'uint16';
		case 8
			config.returnedDataType = 'uint8';
		otherwise
			config.returnedDataType = 'single';
	end
	
	% GET FIRST & LAST FRAME IDX FOR EACH FILE
	numFramesTotal = sum([fileInfo(:).numFrames]);
	
	% ADD TO STACK INFO
	config.numFrames = numFramesTotal;
	config.frameSize = frameSize;
	config.numCols = numCols;
	config.numRows = numRows;
	config.numChannels = numChannels;
	
	
	
	% ----------------------------------------------
	%% FRAME-TO-FILE IDX LOOKUP-TABLE
	% ----------------------------------------------
	
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
	[config.isValidIdx, config.getValidIdx, config.lookupFileIdx, config.lookupRelIdx] = ...
		initializeIdxLookupFcn( numFramesTotal, fileIdxLUT, relativeFrameIdxLUT);
	
	% TEST STORE THE FRAME-INFO PARSING FUNCTION
	try
		% todo
		config.parseFrameInfoFcn = parseFrameInfoFcn;
	catch me
		assignin('base','config',config);
		msg = getReport(me);
		disp(msg);
		rethrow(me)
	end
	
	
	% ----------------------------------------------
	%% INITIALIZE DYNAMIC (TUNABLE) VARIABLES IN TASK-STACK
	% ----------------------------------------------
	control.NumFramesPerRead = 8;
	control.FirstFrameIdx = 1;
	control.LastFrameIdx = numFramesTotal;
	control.NextFrameIdx = 0; % 1:taskCache.NumFramesPerRead;
	state.CurrentFrameIdx = 0;
	state.StreamFinishedFlag = false;
	%stack.Configuration = config;
	
	
catch me
	% MANAGE ERRORS	
	assignin('base','control',control);
	assignin('base','config',config);
	msg = getReport(me);
	disp(msg);
	rethrow(me)
end


end




function [isValidIdx, getValidIdx, lookFileIdx, lookRelativeIdx] = initializeIdxLookupFcn( lastidx, fileidxlut, relframeidxlut)
% CONSTRUCT FUNCTION HANDLES FOR MAPPING INDICES
isValidIdx = @(idx) bsxfun(@and, (idx>=1) , (idx<=lastidx)) ;
getValidIdx = @(idx) idx( isValidIdx(idx)) ;
lookFileIdx = @(idx) fileidxlut( getValidIdx(idx)) ;
lookRelativeIdx = @(idx) relframeidxlut(getValidIdx(idx)) ;

end
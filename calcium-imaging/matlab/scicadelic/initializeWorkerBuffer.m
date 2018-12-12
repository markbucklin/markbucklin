function workerConstValue = initializeWorkerBuffer(bufferInfo)


% buf = distcompdeserialize(bufser);

% SUPPRESS TIFFLIB WARNINGS
warning('off','MATLAB:imagesci:tiffmexutils:libtiffWarning')
warning('off','MATLAB:tifflib:TIFFReadDirectory:libraryWarning')
warning('off','MATLAB:imagesci:Tiff:closingFileHandle')

% GET VARIABLES FOR DEFINING SIZE OF DATA
dataType = bufferInfo.stackInfo.returnedDataType;
frameSize = bufferInfo.stackInfo.frameSize;
stackLastFrameIdx = bufferInfo.stackInfo.numFrames;
blankFrameData = @() zeros( frameSize, dataType) ;

% OPEN TIFF OBJECTS ON WORKER
for k = 1:bufferInfo.stackInfo.numFiles
	fname = bufferInfo.fileInfo(k).fullFilePath;
	workerTiffObj(k) = Tiff(fname, 'r');
	addlistener(workerTiffObj(k), 'ObjectBeingDestroyed', @(src,~) close(src));
end
bufferInfo.tiffObj = workerTiffObj;

% PREALLOCATE OUTPUT BUFFER
parseFcn = bufferInfo.stackInfo.parseFrameInfoFcn;
for k = 1:bufferInfo.framesPerBuffer
	blankdata = blankFrameData();
	[t,info] = parseFcn(workerTiffObj(1));
	datacell{k} = blankdata;
	frameTime(k,1) = t;
	infocell{k} = info;
end

% CONCATENATE OUTPUTS: DATA (NUMERIC) & INFO (STRUCT-ARRAY)
frameData = cat(4, datacell{:});
frameInfo = cat(1, infocell{:});

bufferInfo.frameData = frameData;
bufferInfo.frameInfo = frameInfo;
bufferInfo.frameTime = frameTime;



% % CONCATENATE TO FORM OUTPUT BUFFER (or keep as cell array?)
% % buf.bufferedOutput.frameData = cat(4, fcell{:});
% % buf.bufferedOutput.frameTime = cat(1, tcell{:});
% % buf.bufferedOutput.frameInfo = cat(1, infocell{:});
% 
% % CONSTRUCT FUNCTION HANDLES FOR MAPPING INDICES
% % checkValidIdx = @(frameIdx) frameIdx((frameIdx>=1)&&(frameIdx<=stackLastFrameIdx)) ;
% % buf.assertValidFrameIdx = checkValidIdx;
% % fileIdxLUT = buf.stackInfo.fileIdxLUT;
% % buf.lookupFileIdx = @(frameIdx) fileIdxLUT( checkValidIdx(frameIdx)) ;
% % buf.lookupFileIdx = @(frameIdx) fileIdxLUT(frameIdx(frameIdx<=stackLastFrameIdx)) ;
% % relativeFrameIdxLUT = buf.stackInfo.relativeFrameIdxLUT;
% % buf.lookupRelativeFrameIdx = @(frameIdx) relativeFrameIdxLUT(checkValidIdxLut(frameIdx)) ;
% % buf.lookupRelativeFrameIdx = @(frameIdx) relativeFrameIdxLUT(frameIdx(frameIdx<=stackLastFrameIdx)) ;


% workerConstValue = distcompserialize64(buf);
workerConstValue = bufferInfo;
fprintf('Frame-Buffer Initialized (lab %d)\n', labindex)

end
function [F, frameIdx, t] = readTiffAsync(fileName, frameIdx, timeStampFcn)
% function [f, tiffObjBS] = readTiffAsync(tiffObjBS)
%
% >> c = parcluster('local')
% >> c.JobStorageLocation = 'Z:\.TEMP\';
% >> timeStampFcn = @readHamamatsuTimeFromStart
% >> for k=1:10, taskIn = {fileName, (k-1)*16 + (1:16) , timeStampFcn}; jobIn{k} = taskIn; end
% >> j = createJob(c)
% >> rtask = createTask( j, @readTiffAsync, 2, jobIn )
% % >> readTiffJob = batch(clust, @readTiffAsync, 2, {tiffObj.FileName, frameIdx})
%
% >> import parallel.internal.cluster.CJSSupport
% 
% >> readTiffAsyncOutput = fetchOutputs(readTiffJob)
% tiffObj = distcompdeserialize(tiffObjBS);

% TODO: if isempty taskObj = getCurrentTask; if isempty(taskObj.UserData)....


if nargin < 3
	timeStampFcn = [];
	if nargin < 2
		frameIdx = [];
	end
end

msg = [];
if ~isempty(frameIdx)	
	numFrames = numel(frameIdx);
else
	numFrames = inf;
end
if isempty(timeStampFcn)
	timeStampFcn = .05;
end

try
	
tiffObj = Tiff(fileName);


tagIds = Tiff.TagID;
tagFields = fields(tagIds);
numTagFields = numel(tagFields);
isTagReadable = true(numTagFields,1);
for k=1:numTagFields
	try
		tiffInfo.(tagFields{k}) = tiffObj.getTag(Tiff.TagID.(tagFields{k}));
	catch me
		isTagReadable(k) = false;
	end
end
readableTagFields = tagFields(isTagReadable);
numReadableTagFields = sum(isTagReadable);

% GET DIMENSIONS
numCols = tiffInfo.ImageWidth;
numRows = tiffInfo.ImageLength;
numChannels = tiffInfo.ImageDepth;
numBits = tiffInfo.BitsPerSample;



% f = zeros([numRows, numCols, numChannels, numFrames]);
% INITIALIZE OUTPUT

tryTimeStampFcn = isa(timeStampFcn, 'function_handle');


k=0;
while k < numFrames
	k = k + 1;
	if ~isempty(frameIdx)
		idx = frameIdx(k);
	else
		idx = k;
	end
	
	if (currentDirectory(tiffObj) ~= idx)
		setDirectory(tiffObj, idx);
	end
	f{k} = read(tiffObj);
	
	
	try
		if tryTimeStampFcn
			imDescription = tiffObj.getTag(Tiff.TagID.ImageDescription);
			t(k) = timeStampFcn(imDescription);
		elseif isnumeric(timeStampFcn)
			t(k) = k * timeStampFcn;
		end
	catch me
		msg = getReport(me);
		tryTimeStampFcn = false;
		t(k) = k * timeStampFcn;
	end
	
	if lastDirectory(tiffObj)
		
		break
	end
	
	nextDirectory(tiffObj);

end
	

close(tiffObj);


catch me
	msg = getReport(me);
	close(tiffObj);
end

timeDim = ndims(f{1});
F = reshape(cat( timeDim, f{:}), numRows, numCols, numFrames, numChannels);
% frameIdx = frameIdx(1:k); % TODO




% numCols = tiffObj.getTag(Tiff.TagID.ImageWidth);
% numRows = tiffObj.getTag(Tiff.TagID.ImageLength);
% numChannels = tiffObj.getTag(Tiff.TagID.ImageDepth);
% numBits = tiffObj.getTag(Tiff.TagID.BitsPerSample);

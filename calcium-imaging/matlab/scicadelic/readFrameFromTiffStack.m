function [frameData, frameTime, frameInfo] = readFrameFromTiffStack( stackInfo, frameIdx)


% GRAB ALL CONSTANT (ANONYMOUS) FUNCTIONS
parseinfo = stackInfo.parseFrameInfoFcn;
getvalididx = stackInfo.getValidIdx;
lookfileidx = stackInfo.lookupFileIdx;
lookrelidx = stackInfo.lookupRelIdx;

% RETRIEVE VALID FRAME INDICES & RELATIVE & MAP IDX
frameidx = getvalididx(frameIdx);
fileidx = lookfileidx(frameIdx);
relidx = lookrelidx(frameIdx);

% RETURN IF FRAME INDEX IS EMPTY
numidx = numel(frameidx);
if (numidx < 1)
	frameData = [];
	frameInfo = struct.empty;
	frameTime = [];
	return
end

% PREALLOCATE DATA ARRAY OR USE CELL TO COLLECT DATA
frameSize = stackInfo.frameSize;
timeDim = numel(frameSize) + 1;
dataType = stackInfo.returnedDataType;

if (timeDim == 4) || (timeDim == 3)
	frameData = zeros( [frameSize numidx], dataType);
	prealloc = true;
else
	framedatacell = cell(numidx,1);
	prealloc = false;
end

% LOAD FRAMES ONE AT A TIME
k = 0;
lastfileidx = 0;
tiffObj = Tiff.empty();

while k < numidx
	k = k + 1;
	idx = double(relidx(k));
	fidx = fileidx(k);
	
	% ATTEMPT TO RETRIEVE TIFF-FILE HANDLE FROM CONSTANT DATA CACHE
	if (fidx ~= lastfileidx)
		if isfield(stackInfo,'tiffObj')
			tiffObj = stackInfo.tiffObj(fidx);
		else
			tiffObj = Tiff(stackInfo.fullFilePath{fidx}, 'r');
			addlistener(tiffObj, 'ObjectBeingDestroyed', @(src,~) close(src));
		end
	end
	
	% CHECK THAT TIFF-FILE HANDLE IS VALID
	if isempty(tiffObj) || ~isvalid(tiffObj)
		tiffObj = Tiff(stackInfo.fullFilePath{fidx}, 'r');
		addlistener(tiffObj, 'ObjectBeingDestroyed', @(src,~) close(src));
	end
	
	% CHECK CURRENT TIFF DIRECTORY
	curtiffidx = currentDirectory(tiffObj);
	if (curtiffidx ~= idx)
		setDirectory(tiffObj, idx);
	end
	
	% READ A FRAME OF DATA
	if prealloc
		switch timeDim
			case 3
				frameData(:,:,k) = read(tiffObj);
			case 4
				frameData(:,:,:,k) = read(tiffObj);
		end
	else
		framedatacell{k,1} = read(tiffObj);
	end
	
	% READ TIMESTAMP & FRAMEINFO
	[t, info] = parseinfo(tiffObj);
	
	% FILL IN ANY MISSING INFO
	info.FrameNumber = frameidx(k);
	info.TriggerIndex = fileidx(k);
	
	frameTime(k,1) = t;
	frameInfo(k,1) = info;
	
	if ~lastDirectory(tiffObj)
		nextDirectory(tiffObj);
	end
	
end

% CONCATENATE DATA FROM CELL ARRAY (IF NOT PREALLOCATED)
if ~prealloc
	frameData = cat( timeDim, framedatacell);
end










% SHAVE INVALID DATA OFF THE END
% if ~all(valididx)
% 	frameData = frameData(:,:,:,valididx);
% 	frameTime = frameTime(valididx(:));
% 	frameInfo = frameInfo(valididx(:));
%
% end


% CONCATENATE OUTPUTS: DATA (NUMERIC) & INFO (STRUCT-ARRAY)
% frameData = cat(4, datacell{:});
% frameInfo = cat(1, infocell{:});

% % GRAB PREALLOCATED DATA FROM CONSTANT (OR PREALLOCATE LOCALLY)
% if isfield(bufferInfo, 'frameData')
% 	frameData = bufferInfo.frameData;
% 	frameInfo = bufferInfo.frameInfo;
% 	frameTime = bufferInfo.frameTime;
%
% else
% 	dataType = stackInfo.returnedDataType;
% 	frameSize = stackInfo.frameSize;
% 	frameData = zeros( [frameSize numidx], dataType);
%
%
% end
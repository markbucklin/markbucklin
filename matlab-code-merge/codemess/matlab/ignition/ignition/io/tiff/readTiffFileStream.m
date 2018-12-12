function [videoFrame, streamFinishedFlag, frameIdx] = readTiffFileStream( config, frameIdx)
%function [cFrameData, cFrameTime, cFrameInfo, cFrameIdx, stack] = readTiffFileStream( stack, frameIdx)
% todo, add a last-directory flag?


% SUPPRESS WARNING DISPLAY
persistent warnSuppressed
if isempty(warnSuppressed)
	ignition.io.tiff.suppressTiffWarnings()
	warnSuppressed = true;
end

% ENABLE PERSISTENT STORAGE OF HANDLE TO RECENT TIFF OBJECT
% persistent tiffObj
% persistent priorFileIdx
% if isempty(priorFileIdx)
% 	priorFileIdx = 0;
% end
% if ~isa(tiffObj, 'Tiff')
% 	tiffObj = Tiff.empty();
% end

% GRAB PARSE FUNCTION HANDLE - todo: see if pulling these out is actually faster
%config = stack.Configuration;
parseInfoFcn = config.parseFrameInfoFcn;
getvalididx = config.getValidIdx;
lookfileidx = config.lookupFileIdx;
lookrelidx = config.lookupRelIdx;

% DETERMINE WHICH FRAMES TO READ NEXT
% if nargin > 1
% 	frameIdx = varargin{1};
% else
%if nargin<2 %new
	% frameIdx = stack.NextFrameIdx; %new
	%if (frameIdx(1) <= stack.PriorFrameIdx(end))
		%stack = ignition.io.tiff.preUpdateTiffFileStream(stack);					
		%frameIdx = stack.NextFrameIdx;
% 	end	
% end
if nargin<2
	frameIdx=0;
	[frameIdx,~] = ignition.shared.getNextIdx(frameIdx,16);
	%[frameIdx,streamFinishedFlag] = ignition.shared.getNextIdx(frameIdx,16);
end
	
% RETRIEVE VALID FRAME INDICES & RELATIVE & MAP IDX
frameIdx = getvalididx(frameIdx);
fileIdx = lookfileidx(frameIdx);
relativeFrameIdx = lookrelidx(frameIdx);
numFrames = numel(frameIdx);

% PREALLOCATE STRUCT ARRAY TO COLLECT DATA
% videoFrame = struct(...
% 	'Data',cell(1,numFrames),...
% 	'Info',cell(1,numFrames),...
% 	'Timestamp',cell(1,numFrames),...
% 	'Idx',cell(1,numFrames));
videoFrame = struct(...
	'Data',cell(1,numFrames),...
	'Info',cell(1,numFrames));




% PREALLOCATE CELL TO COLLECT DATA
%cFrameData = cell(1,numFrames);
%cFrameInfo = cell(1,numFrames);
%cFrameTime = cell(1,numFrames);

% ALSO BUILD CELL ARRAY OF FRAME-IDX FROM NUMERIC VECTOR
%cFrameIdx = num2cell(frameIdx(:)');

% RETURN IF FRAME INDEX IS EMPTY
if (numFrames < 1)
	streamFinishedFlag = true;
	return
else
	streamFinishedFlag = false;
end

% LOAD FRAMES ONE AT A TIME
k = 0;

while k < numFrames
	k = k + 1;
	currentRelativeIdx = double(relativeFrameIdx(k));
	currentFileIdx = fileIdx(k);
	
	% CHECK THAT TIFF-FILE HANDLE IS VALID
	% 	if (currentFileIdx ~= priorFileIdx) || isempty(tiffObj) || ~isvalid(tiffObj)
	% todo -> also check that tiffObj.FileName = config.fileName{currentFileIdx})
	tiffObj = Tiff(config.fullFilePath{currentFileIdx}, 'r');
	% 		addlistener(tiffObj, 'ObjectBeingDestroyed', @closeTiffObj);
	tiffCleanup = onCleanup(@() close(tiffObj)); % todo: test to see if this is faster/safer
	% 	end
	
	% CHECK CURRENT TIFF DIRECTORY	
	if (currentDirectory(tiffObj) ~= currentRelativeIdx)
		setDirectory(tiffObj, currentRelativeIdx);
	end
	
	% READ A FRAME OF DATA
	%cFrameData{k} = read(tiffObj);
	videoFrame(k).Data = read(tiffObj);
	
	% READ TIMESTAMP & FRAMEINFO
	[t, info] = parseInfoFcn(tiffObj);
	
	% FILL IN ANY MISSING INFO (videoinput compatible)
	info.FrameNumber = frameIdx(k);
	info.TriggerIndex = fileIdx(k);
	
	% REDUNDANT FRAMEIDX
	info.Idx = frameIdx(k);
	
	% TIMESTAMP
	info.TimeStamp = t;
	
	%cFrameTime{k} = t;
	%cFrameInfo{k} = info;
	
	% ADD TO VIDEO-INFO STRUCTURE
	videoFrame(k).Info = info;
	
	if ~lastDirectory(tiffObj)
		nextDirectory(tiffObj);
	end
	% 	priorFileIdx = currentFileIdx;
	
end

% POST-READ UPDATE
%acquiredFrameIdx = frameIdx;
%stack.PriorFrameIdx = frameIdx;
% taskCache.CurrentTiffObj = tiffObj;


end



% function closeTiffObj(varargin)
% try
% 	tiffObjSrc = varargin{1};
% 	close(tiffObjSrc)
% catch
% end
% end




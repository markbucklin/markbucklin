function [data, frameIdx, fileIdx] = loadTiffFramesAsync(tiffFileName, fileIdx)



% GET INFO ABOUT IMAGE SIZE AND TYPE
tiffObj = Tiff(tiffFileName,'r');
nRows = tiffObj.getTag(tiffObj.TagID.ImageLength);
nCols = tiffObj.getTag(tiffObj.TagID.ImageWidth);
bitsPerPixel = tiffObj.getTag(tiffObj.TagID.BitsPerSample);
bytesPerPixel = bitsPerPixel/8;
if bitsPerPixel == 16
	dataType = 'uint16';
else
	dataType = 'uint8';
end

% PREALLOCATE DATA
M = 2047; %TODO
preallocSize = 512;
data = zeros([nRows, nCols, M], dataType);
frameIdx = NaN(M,1);

% BEGIN LOADING FRAMES
setDirectory(tiffObj, 1)
finishedFlag = false;
m=0;
while ~finishedFlag
	data(:,:,M) = data(:,:,1);
	frameIdx(M) = frameIdx(1);
	while (m < M) 
		m = m+1;
		
		% READ FRAME
		data(:,:,m) = read(tiffObj);
		frameIdx(m) = currentDirectory(tiffObj);
		
		% INCREMENT FRAME (OR FILE)
		if ~tiffObj.lastDirectory()
			tiffObj.nextDirectory();
		else
			finishedFlag = true;
			break			
		end
	end
	M = M + preallocSize;
end

% REMOVE EXCESS/OVERALLOCATED FRAMES
frameIdx = frameIdx(1:m);
data = data(:,:,1:m);

% CLOSE TIFF OBJECT
close(tiffObj)

%       !!!!!!!!!!!!!!!!!!!!!!!  IDEA >> - pass an amount of time as input and have function load as
%       many frames as possible within given amount of time
%    function [data, frameIdx] = loadTiffFramesAsync(tiffFileName, firstFrameIdx, maxLoadTime, maxLoadNum)



% c = parcluster()
% j = createJob(c)
% for k=1:TL.NFiles, tiffTask(k) = createTask(j, @loadTiffFramesAsync, 3, {TL.FullFilePath{k}, k}); end

% tic, submit(j),

% 	wait(j), benchtime(1) = toc, tic, jOut = fetchOutputs(j); toc













% 			M = obj.FramesPerStep;
% 			N = obj.NFrames;
% 			firstIdx = obj.CurrentFrameIdx;
% 			lastIdx = min( firstIdx+M-1, N );
% 			frameIdx = firstIdx:lastIdx;

% 			% LOCAL VARIABLES
% 			M = obj.FramesPerStep;
% 			N = obj.NFrames;
% 			frameIdx = obj.CurrentFrameIdx + (0:M-1);
% 			infoField = fields(obj.AllFrameInfo);
% 			fileIdx = obj.CurrentFileIdx;
%
% 			% FIX FRAME INDICES FOR END-OF-FILE OR CROSS-FILE READS
% 			frameIdx = frameIdx(frameIdx<=N);
% 			subFrameIdx = obj.AllFrameInfo.subframeidx(frameIdx);
%
%
%
% 			% GATHER FRAME INFO FROM CACHE
% 			for kfn=1:numel(infoField)
% 				info.(infoField{kfn}) = obj.AllFrameInfo.(infoField{kfn})(frameIdx);
% 			end
%
% 			% CHECK THAT CURRENT DIRECTORY ALIGNS WITH CURRENT FRAME
% 			if obj.TiffObj(fileIdx).currentDirectory ~= obj.CurrentSubFrameIdx
% 				setDirectory(obj.TiffObj(fileIdx), obj.CurrentSubFrameIdx)
% 			end
%
% 			% READ FRAME
% 			data = read(obj.TiffObj(fileIdx));

% INCREMENT FRAME (OR FILE)
% 			if obj.TiffObj(fileIdx).lastDirectory();
% 				setCurrentFile(obj, fileIdx + 1)
% 			else
% 				obj.TiffObj(fileIdx).nextDirectory();
% 				obj.CurrentSubFrameIdx = obj.CurrentSubFrameIdx + M;
% 				obj.CurrentFrameIdx = obj.CurrentFrameIdx + M;
% 			end
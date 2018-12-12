

%% SELECT/CHECK INPUT SPECIFICATIONS (File Names & Paths)
fullFilePath = selectTiffFiles();


%% START PARALLEL POOL
gcp
numFramesPerBuffer = 8; % numFramesPerTrigger
tic

%%
% bufsizetest = [ 8 16 32 ];
bufsizetest = numFramesPerBuffer;

for ktest = 1:numel(bufsizetest)
	numFramesPerBuffer = bufsizetest(ktest);
	
	%%
	% DEFINE TAG PARSING FUNCTION (CUSTOM DEPENDING ON SOURCE)
	parseFrameInfoFcn = @parseHamamatsuTiffTag;
	
	% CONSTRUCT LINKS TO TIFF FILES (650 ms)
	[stackInfo, fileInfo, allTiffObj] = initializeTiffStack(fullFilePath, parseFrameInfoFcn);
	
	% INITIALIZE PARALLEL WORKERS (<5 ms)
	% 	[bufferInfo, readFrameFcn] = initializeFrameBuffer(stackInfo, fileInfo, numFramesPerBuffer);
	parallelPoolObj = gcp;
	
	% HANDLE TO DISPATCH FUNCTION FOR REMOTE READ ON PARALLEL LAB
	readFrameFcn = @readFrameFromTiffStack;
	
	bt.Initialize = toc;
	
	%%
	frameDispatchIdx = 0;
	bufferIdx = 0;
	% bufferLoadFcn = @loadTiffBuffer;
	
	cumNumFrames = 0;
	cumTimeDispatch = 0;
	cumTimeLoad = 0;
	
	
	%%
	
	tic
	numBufferElements = parallelPoolObj.NumWorkers;
	if (bufferIdx < 1)
		for kBuf = 1:numBufferElements
			bufferIdx = mod(bufferIdx,numBufferElements) + 1;
			frameDispatchIdx = frameDispatchIdx(end)+(1:numFramesPerBuffer);
			bufferFuture(bufferIdx) = parfeval( parallelPoolObj, readFrameFcn, 3, stackInfo, frameDispatchIdx);
		end
	end
	bt.FirstDispatch = toc;
	cumTimeDispatch = cumTimeDispatch + bt.FirstDispatch;
	disp(bt)
	
	
	%%
	
	hWait = waitbar(0, 'Loading as fast as possible');
	n=0;
	while true
		n=n+1;
		looptic = tic;
		
		% LOAD FROM REMOTE BUFFER
		tic
		bufferIdx = mod(bufferIdx,numBufferElements) + 1;				
		[futureIdx, frameData, frameTime, frameInfo] = fetchNext(bufferFuture(bufferIdx));				
		frameIdx = cat(1, frameInfo.FrameNumber);
		
		cumNumFrames = cumNumFrames + numel(frameIdx);
		bt.CurrentLoad = toc;
		cumTimeLoad = cumTimeLoad + bt.CurrentLoad;
		
		
		
		% CHECK IF FINISHED
		if isempty(frameData) || (frameIdx(end) >= stackInfo.numFrames)
			break
		end
		
		% DISPATCH NEXT REMOTE BUFFER
		tic
		frameDispatchIdx = frameDispatchIdx(end)+(1:numFramesPerBuffer);
		bufferFuture(bufferIdx) = parfeval( parallelPoolObj, readFrameFcn, 3, stackInfo, frameDispatchIdx);
		bt.NextDispatch = toc;
		cumTimeDispatch = cumTimeDispatch + bt.NextDispatch;
		
		% SHOW TIME
		cumTimePerFrame = (cumTimeLoad + cumTimeDispatch) / cumNumFrames;
		loadStatusMsg = sprintf(...
			'Frame: %d - Load/Dispatch Time: %3.4g ms/frame',...
			frameIdx(end),cumTimePerFrame*1000);
		waitbar(frameIdx(end)/stackInfo.numFrames, hWait, loadStatusMsg)
		
		% RECORD TOTAL LOAD LOOP TIME
		looptime(n) = toc(looptic);
		
	end
	delete(hWait)
	
	%
	
	fprintf('Finished - Load/Dispatch Time: %3.4g ms/frame\n', cumTimePerFrame*1000)
	
	
	%%
	buftest(ktest).size = numFramesPerBuffer;
	buftest(ktest).tdispatch = cumTimeDispatch;
	buftest(ktest).tload = cumTimeLoad;
	buftest(ktest).tperframe = cumTimePerFrame;
	
end






% 	currentFuture = bufferFuture(bufferIdx);
% 	[frameData, frameTime, frameInfo] = fetchOutputs(currentFuture);
% 	delete(currentFuture)
% 	if frameInfo(end).TriggerIndex > 8

% 		nextFuture(bufferIdx) = parfeval( parallelPoolObj, readFrameFcn, 3, bufferInfo, frameDispatchIdx);

% SWITCH BUFFERS TO CLEAR CURRENT BUFFER WORKSPACE (MEMORY LEAK WORKAROUND)
% 		if (bufferIdx == numBufferElements)
% 			clear bufferFuture
% 			bufferFuture = nextFuture;
% 		end


% loadMsPerFrame = bt.CurrentLoad*1000/numFramesPerBuffer;
% fprintf('Load: buffer %d \t(%3.4g ms/frame)\t',...
% 	bufferIdx, loadMsPerFrame)
% fprintf('%s', repelem('#', 1, ceil(loadMsPerFrame)) )
% fprintf('\n')
%
%
%
% dispatchMs = bt.NextDispatch*1000;
% fprintf('Dispatch: buffer %d \t(%3.4g ms)\t',...
% 	bufferIdx, dispatchMs)
% fprintf('%s', repelem('@', 1, ceil(dispatchMs)) )
% fprintf('\n')







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



%%
bm.tic.start = tic;
numWorkers = 10;
fileName = TL.TiffObj.FileName;
currentFrameIdx = 0;

%%
p = gcp();
addAttachedFiles(p, {which('readTiffAsync.m'), which('readHamamatsuTimeFromStart.m')})
timeStampFcn = @readHamamatsuTimeFromStart;
readChunkFcn = @readTiffAsync;

%%
bm.tic.callall = tic;
for workerIdx = 1:numWorkers
	bm.tic.call(workerIdx) = tic;
	frameIdx = (workerIdx-1)*16 + (1:16) + currentFrameIdx;
	taskArgsIn = {fileName, frameIdx, timeStampFcn};
	f(workerIdx) = parfeval( p, readChunkFcn, 3, taskArgsIn{:}); % parallel.Pool.
	bm.call(workerIdx) = toc(bm.tic.call(workerIdx));
end
bm.callall = toc(bm.tic.callall);
fqueue = f.Parent;

%%
frameChunk = cell(1,numWorkers);
idxChunk = cell(1,numWorkers);
timeChunk = cell(1,numWorkers);
gpuFrameChunk = cell(1,numWorkers);
gpuNewChunk = false(1,numWorkers);

bm.tic.fetchall = tic;
for workerIdx=1:numWorkers
	bm.tic.fetch(workerIdx) = tic;
	% FETCH DATA FROM CURRENT ROUND
	[completedIdx, F, idx, t] = fetchNext(f);
	frameChunk{completedIdx} = F;
	idxChunk{completedIdx} = idx;
	timeChunk{completedIdx} = t;		
	
	bm.fetch(workerIdx) = toc(bm.tic.fetch(workerIdx));
	
	% SEND TO GPU
	if (workerIdx-1) >= 1
		gpuFrameChunk{(workerIdx-1)} = gpuArray(frameChunk{workerIdx-1});
	end
	
	% INITIATE COLLECTION FOR NEXT ROUND
	if (workerIdx-2) >= 1
		
		
		
	end
	
end
gpuFrameChunk{(workerIdx)} = gpuArray(frameChunk{workerIdx});



bm.fetchall = toc(bm.tic.fetchall);

bm.start = toc(bm.tic.start)



function [bufferInfo, loadFrameIdxDispatchFcn] = initializeFrameBuffer(stackInfo, fileInfo, framesPerBuffer)

% DEFAULT INPUTS
if nargin < 3
	framesPerBuffer = [];
end
if isempty(framesPerBuffer)
	framesPerBuffer = 16;
end

% FILL SINGLE 'BUFFER-INFO' STRUCTURE FOR STORAGE ON REMOTE WORKER
bufferInfo.framesPerBuffer = framesPerBuffer;
bufferInfo.stackInfo = stackInfo;
bufferInfo.fileInfo = fileInfo;
% bufferInfo.numOutputArgs = 3;
bufferInfo.parallelPoolObj = gcp;
bufferInfo.numBufferElements = bufferInfo.parallelPoolObj.NumWorkers;


% HANDLE TO DISPATCH FUNCTION FOR REMOTE READ ON PARALLEL LAB
loadFrameIdxDispatchFcn = @loadTiffBuffer;


end







% bufferInfo.tiffObj = allTiffObj;





% USE PARALLEL POOL CONSTANT TO STORE BUFFER INFO WITH TIFF-FILE HANDLES
% if exist('parallel.pool.Constant','class')
% 	bufferConst = parallel.pool.Constant( @()initializeWorkerBuffer(bufferInfo), @releaseWorkerBuffer);
% 	
% elseif exist('WorkerObjWrapper','class')
% 	% IF VERSION IS BEFORE 2015B USE WORKER-OBJ-WRAPPER (FILE-EXCHANGE)
% 	bufferConst = WorkerObjWrapper( @initializeWorkerBuffer, { bufferInfo }, @releaseWorkerBuffer);
% 	
% else
% 		for k=1:numel(fileInfo)
% 			bufferInfo.tiffObj(k) = Tiff(fileInfo(k).fullFilePath , 'r');
% 		end
% 		bufferConst.Value = bufferInfo;
% 	
% end

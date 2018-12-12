
% TIFF STACK
[stackInfo,fileInfo,allTiffObj] = ignition.io.tiff.initializeTiffStack();
[frameData,frameTime,frameInfo] = ignition.io.tiff.readFrameFromTiffStack(stackInfo, 1:32);
[F, reverseFormatFcn] = ignition.shared.formatVideoNumericArray(frameData);
frameIdx = ignition.shared.getNextIdx([],16);
args = {stackInfo, frameIdx};
numOut = 3;
readFcn = @ignition.io.tiff.readFrameFromTiffStack;

% PARALLEL TIFF LOAD
futureObj = parfeval( readFcn, numOut, args{:} );
frameIdx = ignition.shared.getNextIdx(frameIdx, [], stackInfo.numFrames);

% PARALLEL FUTURE INTERNALS
sfutureObj = struct(futureObj);
scacheIn = struct(sfutureObj.InputCache);
scacheOut = struct(sfutureObj.OutputCache);
sQueue = struct(sfutureObj.Parent);
function [rowSubs, colSubs, chanSubs, frameSubs] = getVideoSegmentSubscripts(F)

[numRows,numCols,numChannels,numFrames] = size(F);

rowSubs = int32(gpuArray.colon(1,numRows)');
colSubs = int32(gpuArray.colon(1,numCols));
chanSubs =  int32(reshape(gpuArray.colon(1, numChannels), 1, 1, numChannels));
frameSubs =  int32(reshape(gpuArray.colon(1, numFrames), 1, 1, 1, numFrames));

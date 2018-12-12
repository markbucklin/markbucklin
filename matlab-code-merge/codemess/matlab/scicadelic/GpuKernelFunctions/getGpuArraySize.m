function gSize = getGpuArraySize(F)

gSize = gpuArray(int32(size(F)));

% numRows = gpuArray(int32(n1));
% numCols = gpuArray(int32(n2));
% numFrames = gpuArray(int32(n3));
% if nargout>3
% 	varargout{1} = gpuArray(int32(n4));
% end








% function [numRows,numCols,numFrames,varargout] = getGpuArraySize(F)
% 
% [n1,n2,n3,n4] = size(F);
% numRows = gpuArray(int32(n1));
% numCols = gpuArray(int32(n2));
% numFrames = gpuArray(int32(n3));
% if nargout>3
% 	varargout{1} = gpuArray(int32(n4));
% end
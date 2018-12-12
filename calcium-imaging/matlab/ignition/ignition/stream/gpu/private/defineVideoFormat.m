% FULL FORMAT OF CALLING FUNCTION
% persistent rowDim colDim channelDim frameDim
% persistent numRows numCols numChannels numFrames
% persistent rowSubs colSubs chanSubs frameSubs
% persistent numPixels
% if isempty(numPixels) || (numel(F) ~= numPixels)
% 	defineVideoFormat
% end



% DEFINE DIMENSIONS
if exist('rowDim', 'var') 
	rowDim = 1;
end
if exist('colDim', 'var')
	colDim = 2;
end
if exist('channelDim', 'var')
	channelDim = 3;
end
if exist('frameDim', 'var')
	frameDim = 4;
end

% GET SIZE OF VIDEO SEGMENT IN EACH DIMENSION
if exist('numRows', 'var')
	numRows = size(F,1);
end
if exist('numCols', 'var')
	numCols = size(F,2);
end
if exist('numChannels', 'var')
	numChannels = size(F,3);
end
if exist('numFrames', 'var')
	numFrames = size(F,4);
end

% GET SUBSCRIPTS FOR SAMPLES IN EACH DIMENSION
if exist('rowSubs', 'var')
	rowSubs = int32(reshape(gpuArray.colon(1,size(F,1)), size(F,1), 1));
end
if exist('colSubs', 'var')
	colSubs = int32(reshape(gpuArray.colon(1,size(F,2)), 1, size(F,2)));
end
if exist('chanSubs', 'var')
	chanSubs = int32(reshape(gpuArray.colon(1,size(F,3)), 1, 1, size(F,3)));
end
if exist('frameSubs', 'var')
	frameSubs = int32(reshape(gpuArray.colon(1,size(F,4)), 1, 1, 1, size(F,4)));
end

% USE NUM-PIXELS TO STORE/INDICATE SIZE OF LAST INPUT
numPixels = numel(F);


% % DEFINE DIMENSIONS
% rowDim = 1;
% colDim = 2;
% channelDim = 3;
% frameDim = 4;
%
% % GET SIZE OF VIDEO SEGMENT IN EACH DIMENSION
% [numRows,numCols,numChannels,numFrames] = size(F);
%
% % GET SUBSCRIPTS FOR SAMPLES IN EACH DIMENSION
% rowSubs = int32(gpuArray.colon(1,numRows)');
% colSubs = int32(gpuArray.colon(1,numCols));
% chanSubs =  int32(reshape(gpuArray.colon(1, ...
% 	numChannels), 1, 1, numChannels));
% frameSubs =  int32(reshape(gpuArray.colon(1, ...
% 	numFrames), 1, 1, 1, numFrames));
%
% % USE NUM-PIXELS TO STORE/INDICATE SIZE OF LAST INPUT
% numPixels = numRows * numCols * numChannels * numFrames;

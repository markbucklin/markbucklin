function [numChannels, numFrames] = getNumChannelsAndFrames(F)
% getNumChannels - return number of channels in an image or video frame
%
% >> numChannels = getNumChannels(F)
% >> numChannels = getNumChannels(videoFrameObject)

channelDim = 3;
frameDim = 4;


if isempty(F)
	% EMPTY INPUT
	numChannels = 0;
	numFrames = 0;
	return
end



% CALCULATION OF FRAME SIZE DEPENDS ON TYPE & DIMENSION OF INPUT
if isnumeric(F)
	% NUMERIC ARRAY INPUT
	numChannels = size(F, channelDim);
	numFrames = size(F, frameDim);
	
else
	if iscell(F)
		% CELL ARRAY INPUT
		numChannels = max(sum(cellfun(@size, F, repmat({channelDim},size(F))) , 1), [], 2);
		numFrames = max(sum(cellfun(@size, F, repmat({frameDim},size(F))) , 2), [], 1);
		
	elseif (isa(F, 'ignition.core.type.DataContainerBase'))
		% DATA-CONTAINER CLASS OBJECT INPUT
		containerArraySize = size(F);
		subContainerSize = cat(1, F.DataSize);
		subContainerChannels = reshape(subContainerSize(:,channelDim), containerArraySize);
		subContainerFrames = reshape(subContainerSize(:,frameDim), containerArraySize);
		numChannels = max(sum(subContainerChannels, 1),[],2);
		numFrames = max(sum(subContainerFrames, 2),[],1);
		
	elseif (isstruct(F))
		[numChannels, numFrames] = size(F);
		
	else
		% UNKNOWN -> ERROR
		error('unknown input')
		
	end
	
end





function numChannels = getNumChannels(F)
% getNumChannels - return number of channels in an image or video frame
%
% >> numChannels = getNumChannels(F)
% >> numChannels = getNumChannels(videoFrameObject)

channelDim = 3;


if isempty(F)
	% EMPTY INPUT
	numChannels = 0;
	return
end



% CALCULATION OF CHANNEL SIZE DEPENDS ON TYPE & DIMENSION OF INPUT
if isnumeric(F)
	% NUMERIC ARRAY INPUT
	numChannels = size(F, channelDim);
	
else
	if iscell(F)
		% CELL ARRAY INPUT
		numChannels = max(sum(cellfun(@size, F, repmat({channelDim},size(F))) , 1), [], 2);
		
	elseif (isa(F, 'ignition.core.type.DataContainerBase'))
		% DATA-CONTAINER CLASS OBJECT INPUT
		containerArraySize = size(F);
		subContainerSize = cat(1, F.DataSize);
		subContainerChannels = reshape(subContainerSize(:,channelDim), containerArraySize);
		numChannels = max(sum(subContainerChannels, 1),[],2);
		
		% VIDEO-FRAME (SUBCLASS OF DATA-CONTAINER-BASE)
		% 	numFrames = getNumFrames(F);
		
	elseif (isstruct(F))
		numFrames = size(F,2);
		
	else
		% UNKNOWN -> ERROR
		error('unknown input')
		
	end
	
end







% % NUMERIC ARRAY INPUT
% if isnumeric(F)
% 	numFrames = size(F,4);
% else
% 	numFrames = size(F,2);
% end

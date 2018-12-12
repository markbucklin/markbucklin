function numFrames = getNumFrames(F)
% GETFRAMESIZE return number of rows columns and channels in an image or video frame
%
% >> numFrames = getNumFrames(F)
% >> numFrames = getNumFrames(videoFrameObject)

frameDim = 4;

if isempty(F)
	% EMPTY INPUT
	numFrames = 0;
	return
end

% CALCULATION OF FRAME SIZE DEPENDS ON TYPE & DIMENSION OF INPUT
if isnumeric(F)
	% NUMERIC ARRAY INPUT
	numFrames = size(F, frameDim);
	
else
	if iscell(F)
		% CELL ARRAY INPUT
		numFrames = max(sum(cellfun(@size, F,...
			num2cell(frameDim.*ones(size(F)))) , 2), [], 1);
				
	elseif isobject(F)
		% isa(F, 'ignition.core.type.DataContainerBase')
		% DATA-CONTAINER CLASS OBJECT INPUT -> CHECK IF SUBTYPE IS VIDEOFRAME (single)
		if isa(F, 'ignition.core.type.VideoFrame')
			% VIDEO-FRAME (SUBCLASS OF DATA-CONTAINER-BASE)
			numFrames = size(F,2); % or numel(F);
			% alternatively, get number of unique Idx...??
			
		else
			% OTHER GENERIC (multi-frame??) DATA-CONTAINER CLASS OBJECT INPUT
			containerArraySize = size(F);
			subContainerSize = cat(1, F.DataSize);
			subContainerFrames = reshape(subContainerSize(:,frameDim), containerArraySize);
			numFrames = max(sum(subContainerFrames, 2),[],1);
			% todo: take max?? --> returns single scalar value rather than 1 for each channel
			
		end
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

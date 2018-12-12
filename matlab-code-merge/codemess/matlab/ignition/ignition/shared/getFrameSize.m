function [numRows,numCols,numChannels] = getFrameSize(F)
% GETFRAMESIZE return number of rows columns and channels in an image or video frame
%
% >> [numRows,numCols,numChannels] = getFrameSize(F)
% >> [numRows,numCols,numChannels] = getFrameSize(videoFrameObject)

channelDim = 3;


if isempty(F)
	% EMPTY INPUT
	numRows = 0;
	numCols = 0;
	numChannels = 0;
	return
end

% CALCULATION OF FRAME SIZE DEPENDS ON TYPE & DIMENSION OF INPUT
if isnumeric(F)
	% NUMERIC ARRAY
	[numRows,numCols,numChannels] = getFrameSizeFromNumericArray(F);
		
else
	if iscell(F)
		% CELL ARRAY INPUT
		if size(F,1) ==1
			[numRows,numCols,numChannels] = getFrameSizeFromNumericArray(F{1});
		else
			[numRows,numCols,numChannels] = getFrameSizeFromNumericArray(cat(3,F{:,1}));
		end
		%numRows = max(max(cellfun(@size, F, repmat({[1]},size(F))) ,[], 2));
		%numCols = max(max(cellfun(@size, F, repmat({[2]},size(F))) ,[], 2));
		%numChannels = sum( max(cellfun(@size, F, repmat({[3]},size(F))) ,[], 2), 1);
		
	elseif isobject(F) % (isa(F, 'ignition.core.type.DataContainerBase'))
		% DATA-CONTAINER CLASS OBJECT
		containerArraySize = size(F);
		subContainerSize = cat(1, F.DataSize);
		
		% ROWS & COLUMNS SHOULD BE CONSISTENT
		rowscols = max(subContainerSize(:,1:2), [],  1);
		numRows = rowscols(1);
		numCols = rowscols(2);
		
		% GET CHANNELS BY ADDING UP MAX SUB-CONTAINER SIZE ACROSS 1ST-DIM
		subContainerChannels = reshape(subContainerSize(:,channelDim), containerArraySize);
		numChannels = sum(max(subContainerChannels,[],2), 1);
		
		% 	[numRows,numCols,numChannels] = getFrameSize(F);
		
		% TODO -> STRUCT
		
	else
		% UNKNOWN -> ERROR
		error('unknown input')
	end
	
end

end

function [d1,d2,d3] = getFrameSizeFromNumericArray(f)
[d1, d2, d3, d4] = size(f);
	if (d4 == 1) && (d3 > 3)
		warning('ignition:shared:getFrameSize:AmbiguousChannelFrameDimension',...
			['The dimension for sequential video frames cannot be distinguished from ',...
			'the dimension for a multi-channel image if input is 3D. Assuming input ',...
			'is meant to be single-frame and multi-channel. ',...
			'[ignition:shared:getFrameSize:AmbiguousChannelFrameDimension]'])
	end
	
	

end



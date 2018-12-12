function [idx, maxLastIdxFlag] = getNextIdx(idx, numIdx, maxIdx)
% getNextIdx - Return scalar or vector of updatable sequential indices
%
% Syntax:
%			>> idx = getNextIdx();
%			>> idx = getNextIdx(0, numIdx);
%			>> idx = getNextIdx([], numIdx);
%			>> idx = getNextIdx(idx);
%			>> idx = getNextIdx(idx, numIdx);
%			>> [idx, maxLastIdxFlag] = getNextIdx(idx, numIdx, maxIdx)
%			>> [idx, maxLastIdxFlag] = getNextIdx(idx, [], maxIdx)
%
% todo: make an incrementer handle class that increments & returns boolean
%
% 3-8 microseconds

% DEFAULTS FOR OPTIONAL INPUTS/OUTPUTS
maxLastIdxFlag = false;
if (nargin < 1)
	idx = 0;
elseif isempty(idx)
	idx = 0;
end
if (nargin < 2)
	numIdx = [];
end
if isempty(numIdx)
		numIdx = numel(idx);		
end
if (nargin < 3)
	maxIdx = inf;
end

% GET FIRST/LAST IDX
priorIdx = idx(end);
firstIdx = priorIdx + 1;
lastIdx = priorIdx + numIdx;

% RESTRICT TO VALUES LESS THAN SPECFIED MAXIMUM IDX
assert( priorIdx < maxIdx, ...
	'Next sequential index exceeds the specified maximum index')
lastIdx = min( lastIdx, maxIdx);

% DETERMINE NUMBER OF INDICES THAT WILL BE RETURNED
numValidIdx = lastIdx - priorIdx;

% PREPARE FOR RESHAPING FOR N-D COMPATIBILITY
idxSize = size(idx);
idxDims = ndims(idx);

% CONSTRUCT INCREMENTED IDX
idx = firstIdx:lastIdx;

% RESHAPE IF N-D ARRAY IS GIVEN AS INPUT
if (idxDims > 2)
	if (numValidIdx ~= numIdx)
		idxSize(idxDims) = numValidIdx;
	end
	idx = reshape(idx, idxSize);
end

% SET MAX-LAST-IDX FLAG IF MAX INCREMENT HAS REACHED MAX
if (idx(end) == maxIdx)
	maxLastIdxFlag = true;
end


end




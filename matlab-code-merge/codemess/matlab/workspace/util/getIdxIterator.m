function [getNextIdx, idx] = getIdxIterator( idxStart, idxFinish, numIdx)
%
%
%			>> getNextIdx = getIdxIterator();
%			>> idx = getNextIdx();
%			>> [getNextIdx, idx] = getIdxIterator();
%			>> idx = getNextIdx(idx);
%			>> [getNextIdx, idx] = getIdxIterator(0, 100, 8);
%			>> idx = nextIdx(idx);
%

if nargin<3, numIdx = 1; end
if nargin<2, idxFinish = inf; end
if nargin<1, idxStart = 0; end

% HELPER FUNCTIONS -> CALLED BY RETURNED FCN-HANDLE
getPrevFcn = @(varargin) getPrevIdx( idxStart, varargin{:});
getNextFcn = @(idxPrev) genNextIdx( idxPrev, idxFinish, numIdx);

% MAIN FUNCTION-HANDLE RETURNED
getNextIdx = @(varargin) getNextFcn( getPrevFcn(varargin{:}));

% INITIALIZE
idx = getNextIdx();

end

function idx = getPrevIdx( idxStart, idx)
if nargin < 2
	idx = idxStart;
end
end

function idx = genNextIdx(idx, idxFinish, numIdx)
if ~isempty(idx)
	idx = idx(end) + (1:numIdx);
	idx = idx(idx<=idxFinish);
end
end



% TODO: compare to ignition.shared.getNextIdx





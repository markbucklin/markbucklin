function ovmap = linkLabelMatrices( r1IdxMat, r2IdxMat)



r1Idx = [1:max(r1IdxMat(:))]';
r2Idx = [1:max(r2IdxMat(:))]';


pxOverlap = bsxfun(@and, logical(r1IdxMat) , logical(r2IdxMat));
idx2idxMap = [r1IdxMat(pxOverlap) , r2IdxMat(pxOverlap)]; % could distribute here along 2nd dim
uniqueIdxPairMap = unique(idx2idxMap, 'rows');

if ~issparse(r1IdxMat)
% COUNT & SORT BY RELATIVE AREA OF OVERLAP
overlapCount = zeros(size(uniqueIdxPairMap),'like',uniqueIdxPairMap); % overlapCount = zeros(size(uniqueIdxPairMap), 'single');
for k=1:size(idx2idxMap,2)
	pxovc = accumarray(idx2idxMap(:,k),1); % pxovc = accumarray(idx2idxMap(:,k),single(1));
	overlapCount(:,k) = pxovc(uniqueIdxPairMap(:,k));
end
pxOverlapCount = single(min(overlapCount,[],2));

r1Area = accumarray(nonzeros(r1IdxMat), 1);
r2Area = accumarray(nonzeros(r2IdxMat), 1);
uidxOrderedArea = [r1Area(uniqueIdxPairMap(:,1)) , r2Area(uniqueIdxPairMap(:,2))];
fractionalOverlapArea = bsxfun(@rdivide, pxOverlapCount, uidxOrderedArea);
[~, fracOvSortIdx] = sort(prod(fractionalOverlapArea,2), 1, 'descend');
idx = uniqueIdxPairMap(fracOvSortIdx,:);

ovmap.area = uidxOrderedArea(fracOvSortIdx,:);
ovmap.fracovarea = fractionalOverlapArea(fracOvSortIdx,:);

else
	idx = uniqueIdxPairMap;
end

% ALSO RETURN UNMAPPED REGIONS
mappedR1 = false(size(r1Idx));
mappedR2 = false(size(r2Idx));
mappedR1(idx(:,1)) = true;
mappedR2(idx(:,2)) = true;
unMappedLabels = {r1Idx(~mappedR1), r2Idx(~mappedR2)};

% OUTPUT IN STRUCTURE
% ovmap.uid = uniqueUidPairMap(fracOvSortIdx,:);
ovmap.idx = idx;
ovmap.mapped = [r1Idx(idx(:,1)) , r2Idx(idx(:,2))];
ovmap.unmapped = unMappedLabels;
ovmap.overlap = pxOverlap;
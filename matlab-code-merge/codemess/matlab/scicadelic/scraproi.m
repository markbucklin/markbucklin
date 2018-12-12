
parfor k=1:numel(rps)
	sfroi(k) = RegionOfInterest(rps(k), 'FrameSize',frameSize);
end




cxy = cat(1,sfroi.Centroid);

gridSpace = 8;

idx = gridSpace/2:gridSpace:1024;
h3 = bsxfun(@and,...
	(abs(bsxfun(@minus, cxy(:,1), idx(:)')) < gridSpace+1) ,...
	(abs(bsxfun(@minus, cxy(:,2), reshape(idx, 1,1,[]))) < gridSpace+1));

imagesc(squeeze(sum(h3,1)))

hGridSum = squeeze(sum(h3,1));
[gridNum, gridIdx] = sort(hGridSum(:),'descend');
groups = cell.empty(numel(gridIdx),0);
[gRow,gCol] = ind2sub(frameSize, gridIdx);

h3r = reshape(h3, size(h3,1),[]);

for k=1:numel(gridIdx)
	groups{k} = sfroi( h3r(:,gridIdx(k)) );
end

groups = groups(~cellfun('isempty',groups));
numInGroup = cellfun(@numel, groups);
lonelyGroups = groups(numInGroup == 1);
pairGroups = groups(numInGroup == 2);
groups = groups(numInGroup >= 3);

numBefore = zeros(size(groups(:)));
numAfter = zeros(size(groups(:)));
parfor k=1:numel(groups)
	roiGroup = groups{k};
	roiGroup = roiGroup(isvalid(roiGroup));
	ng = numel(roiGroup)
	numBefore(k) = ng;
	if ng > 1
		rg = reduceSuperRegions(roiGroup);
		numAfter(k) = numel(rg);
		Rmerged{k,1} = rg;
	elseif ng == 1
		rg = roiGroup;
		numAfter(k) = numel(rg);
		Rmerged{k,1} = rg;
	end
end

R = cat(1,Rmerged{:});
R = R([isvalid(R)]);
R = R([R.Area] < 1000);






tic


if isa(lm, 'gpuArray')
	lm = gather(lm);
end

minArea = 25;
currentIdx = 0;
codist = codistributor1d(3);
spmd(8)
	lmDist=codistributed(logical(lm), codist); 
	rp = regionprops(getLocalPart(lmDist),'Area','Centroid','BoundingBox','PixelIdxList');
	rpArea = [rp.Area];
	rp = rp(rpArea>minArea);
	R = LinkedRegion(rp, 'FrameIdx', currentIdx+labindex);
	fprintf('lab-%i \t %i regions\n',labindex, numel(rp))
	
	
	if labindex < numlabs
		
	end
end
toc


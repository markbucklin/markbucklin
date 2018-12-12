



maxArea = 1500;
regionAlloc = 4096;






lm = labelMatrix(:,:,1);
numPix = numel(lm);
lm = reshape(lm, numPix,1);
splm = spalloc(numPix, regionAlloc, round(regionAlloc*maxArea));
for k=1:max(lm)
	px = (lm == k);
	splm(px,k) = k;
end



spbw = logical(splm);
spov = bsxfun(@and, bw(:), spbw);


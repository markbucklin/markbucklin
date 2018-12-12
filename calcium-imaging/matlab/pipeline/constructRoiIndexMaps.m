function setidx = constructRoiIndexMaps(roi)
% CONSTRUCT INDEX VECTORS THAT MAP PIXEL INDICES TO ROIs (FROM GROUPING VARIABLES)
roiArea = cat(1,roi.Area);
setidx.roipix = cat(1,roi.PixelIdxList);
roiFirstIdxIdx = [1 ; cumsum(roiArea)+1];
r1 = roiFirstIdxIdx;
r2 = [ r1(2:end)-1 ; numel(setidx.roipix)];
for kRoi = 1:numel(r1)
  setidx.roimap(r1(kRoi):r2(kRoi),1) = kRoi;
end

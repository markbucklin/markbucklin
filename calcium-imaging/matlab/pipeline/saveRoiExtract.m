function saveRoiExtract(singleFrameRoi,fdir)


sfroiPixIdx = cell(numel(singleFrameRoi),1);
for k=1:numel(singleFrameRoi)
   sfroiPixIdx{k,1} = singleFrameRoi(k).PixelIdxList;
end
sfroi.pixidx = sfroiPixIdx;
sfroi.frame = cat(1,singleFrameRoi.Frames);
sfroi.cxy = cat(1,singleFrameRoi.Centroid);
save(fullfile(fdir,'singleframeroiEXTRACTv6'),'sfroi', '-v6')
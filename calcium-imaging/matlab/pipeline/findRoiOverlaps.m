






ht=hat;
roiFrameIdx = [roi.Frames];
frameNumbers = unique(roiFrameIdx);
parfor kFrame = 1:numel(frameNumbers)
  fnum = frameNumbers(kFrame);
  roifn = roi(roiFrameIdx == fnum);
  roipost = roi(roiFrameIdx > fnum);
  ovlp = overlaps(roifn, roipost);
  for kRoi = 1:numel(roifn)
    roiPostOvlp = roipost(ovlp(kRoi,:)');
    roifn(kRoi).OverlappingRegion = roiPostOvlp(:);
    % TODO: add roifn to overlapping regions of roipostovlp
  end
end
    
%   overLap{kFrame} = ovlp;

ht = hat-ht % 500frames:16s, 1000frames:64s
  
%   fov{k} = roi(k).fractionalOverlap(roi(k+1:250)); end, 


%   roi(k).OverlappingRegion = roi( overlaps( roi(k), roi)); % 83 minutes for 6084^2 calculations  
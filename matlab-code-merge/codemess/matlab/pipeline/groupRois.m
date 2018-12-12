function [mergedRoi, varargout] = groupRois(roi)
% groups ROIs from each frame with close

roiAll = roi;
N = numel(roiAll);
ar.eccentricity = [roiAll.Eccentricity];
ar.area = [roiAll.Area];
ar.centroids = cat(1,roiAll.Centroid);
csThresh = 5; % (centroid-separation maximum threshold in pixels)

%% TRACE CELLS AND SEPARATE INTO (too)SMALL, MEDIUM, (too)LARGE
% note: also need to provide a video frame if user-interaction is desired
% ui = false;
% if ui
%   % ASK FOR USER INPUT TO DETERMINE RANGE OF TARGET ROI AREA
%   waitfor(msgbox('Trace a few cells to give an approximation of the target cell size'));
%   vidSample = getVidSample(vid);
%   sampleImage = mat2gray( range( cat(3, vidSample.cdata), 3));
%   imshow(sampleImage);
%   doAnotherRoi = 'yes';
%   nRoi = 0;
%   while(strcmpi(doAnotherRoi,'yes'))
% 	 nRoi = nRoi +1;
% 	 hRoi(nRoi) = impoly(gca);
% 	 doAnotherRoi = questdlg('Trace Another Cell?');
%   end
%   for k = 1:numel(hRoi)
% 	 cMask = hRoi(k).createMask;
% 	 maskArea(k) = sum(cMask(:));
% 	 cellMask(:,:,k) = cMask;
%   end
%   bgMask = sum(cellMask,3);
%   imshowpair(sampleImage, bgMask);
%   drawnow
%   crit.maxArea = max(maskArea) + std(maskArea)/2;
%   crit.minArea = min(maskArea) - std(maskArea)/2;
% else
% DEFINE MIN/MAX AREA RESTRICTIONS
%   crit.maxArea = 350;
%   crit.minArea = 75;
% end
% tooSmall = ar.area < crit.minArea;
% tooBig = ar.area > crit.maxArea;
% roiSmall = roi(tooSmall);
% roiBig = roi(tooBig);
% roiJustRight = roi( ~(tooSmall | tooBig));
% roi = roiJustRight;

%% FORM GROUPS FROM NEW ROIS AND ADD SIMILAR ROIS TO EXISTING GROUPS
try
  firstFrame = roi(1).Frames(1);
  roiThisFrame = roi([roi.Frames] == firstFrame);
  nGroups = numel(roiThisFrame);
  for kGroup = 1:nGroups
    roiGroups{kGroup} = roiThisFrame(kGroup);
  end
  roiGroupPower = ones(nGroups,1);
  for kFrame = (firstFrame+1) : roi(end).Frames(end) %note: may need to sort input by frame numbers later if function to take superrois
    fprintf('ROI Groups: %i \tFrame: %i\n',...
      nGroups, kFrame);
    roiThisFrame = roi([roi.Frames] == kFrame);
    nPrevGroups = nGroups;
    % COMPARE MOST RECENT ROI FROM EACH EXISTING GROUP TO CURRENT ROIs
    for kGroup = 1:nPrevGroups
      groupedSet = roiGroups{kGroup};
      groupedRoi = groupedSet(end);
      csep = groupedRoi.centroidSeparation(roiThisFrame);
      dUnder = csep<csThresh;
      % ADD MOST SIMILAR ROI TO EXISTING GROUP (IF UNDER CENTROID-SEPARATION THRESHOLD)
      if any(dUnder)
        [~,idx] = min(csep(:));
        similarRoi = roiThisFrame(idx);
        roiGroups{kGroup} = cat(1, groupedSet(:), similarRoi);
        roiGroupPower(kGroup) = roiGroupPower(kGroup) + 1;
        roiThisFrame = roiThisFrame(~dUnder);
      end
    end
    % FORM NEW SINGLETON GROUPS FROM ANY REMAINING/UNMATCHED ROIs
    if numel(roiThisFrame) >= 1
      nGroups = nPrevGroups + numel(roiThisFrame);
      newGroupIdx = nPrevGroups+1 : nGroups;
      for kNew = 1:numel(roiThisFrame)
        idx = newGroupIdx(kNew);
        roiGroups{idx} = roiThisFrame(kNew);
        roiGroupPower(idx) = 1;
      end
    end
  end
  
  
  %% MERGE & COMBINE EACH GROUP OF REGIONS INTO A 'SUPER-REGION'
  for kGroup=1:nGroups
    try
      fprintf('Identifying unique ROIs in group %i\n',kGroup)
      uObj = unique(roiGroups{kGroup});
      fprintf('\t%i unique ROIs\n',numel(uObj));
      mroi = merge(uObj);
      if numel(mroi) > 1
        [~,idx] = max([mroi.Area]);
        mroi = mroi(idx);
      end
      croi = combine(uObj);
      if numel(croi) > 1
        [~,idx] = min([croi.Area]);
        croi = croi(idx);
      end
      mergedRoi(kGroup) = mroi;
      combinedRoi(kGroup) = croi;
    catch me
      disp(me.message)
      keyboard
    end
  end
  mergedRoi = removeEmpty(mergedRoi);
  mergedRoi = mergedRoi(:);
  combinedRoi = removeEmpty(combinedRoi);
  combinedRoi = combinedRoi(:);
catch me
  keyboard
end

%% EXTRACT MASK OF ALL ROIS
% mask.merged = mergedRoi(1).Mask;
% mask.combined = combinedRoi(1).Mask;
% for k=2:numel(mergedRoi)
%   if ~isempty(mergedRoi(k).PixelIdxList)
% 	 mask.merged = or( mergedRoi(k).Mask, mask.merged);
%   end
%   if ~isempty(combinedRoi(k).PixelIdxList)
% 	 mask.combined = or( combinedRoi(k).Mask, mask.combined);
%   end
% end

% sampleImage = range( cat(3, vidSample.cdata), 3);
% stat = getVidStats(vid);
% sampleImage = stat.Range;
% rgbim(:,:,2) = sampleImage;
% rgbim(:,:,1) = uint8(mask.combined).*50;
% rgbim(:,:,3) = uint8(mask.merged).*200;
% imshow(rgbim)

%% OVERLAP
% rgbvid = zeros([size(vid(1).cdata) 3 numel(vid)], 'uint8');
% rgbvid(:,:,2,:) = cat(4,vid.cdata);
% for kRoi = 1:numel(mergedRoi)
%   fprintf('adding blue channel for roi %i\n',kRoi);
%   fn = mergedRoi(kRoi).Frames;
%   if ~isempty(mergedRoi(kRoi).Mask)
% 	 rgbvid(:,:,3,fn) = uint8(or( rgbvid(:,:,3,fn), repmat(mergedRoi(kRoi).Mask,[1 1 1 numel(fn)]))).*180;
%   elseif ~isempty(mergedRoi(kRoi).SubRegion(1).Mask)
% 	 rgbvid(:,:,3,fn) = uint8( or( rgbvid(:,:,3,fn), repmat(mergedRoi(kRoi).SubRegion(1).Mask,[1 1 1 numel(fn)]))).*100;
%   end
% end

%% TRACES
% vidarray = cat(3,vid.cdata);
% for kRoi = 1:numel(mergedRoi)
%   pxidx = mergedRoi(kRoi).PixelIdxList;
%   if ~isempty(pxidx)
% 	 [ysub, xsub] = ind2sub(mergedRoi(kRoi).FrameSize, pxidx);
% 	 mergedRoi(kRoi).Trace = mean(reshape(vidarray(ysub,xsub,:), numel(pxidx), []), 1);
%   end
% end

%%
% 	 if isempty(roiThisFrame)
% 		break
% 	 end
% 	 bb = groupedRoi.isInBoundingBox(roiThisFrame);
% If there's any overlap, check whether it's bisubstantial
% 	 if any(bb)
% 		similarRoi = roiThisFrame(bb);
% 		[thisoverall, alloverthis] = groupedRoi.fractionalOverlap(similarRoi);
% If overlap is bisubstantial, add ROI from current frame to that group
% 		if (thisoverall > .25) || (alloverthis > .25)
% 		ovlp = groupedRoi.fractionalOverlap(similarRoi);
% 		if any(ovlp > .25)
% 		  [~,idx] = max(ovlp(:));

% 	 else
% 		roiGroups(kFrame,kGroup) = groupedRoi;
% 	 end

if nargout > 1
  varargout{1} = combinedRoi;
end


















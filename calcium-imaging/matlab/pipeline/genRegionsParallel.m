function [mRoi, cRoi] = reduceRegions(roi)

try
  %%
  N = numel(vid);
  %   myCluster = parcluster('local');
  pp = gcp;
  %% SPLIT DATA INTO BATCHES FOR PARALLEL PROCESSING
  nBatchFrames = 127;
  firstFrames = 1:nBatchFrames:N;
  lastFrames = [firstFrames(2:end)-1 N];
  nBatches = numel(firstFrames);
  vidBatch = cell(nBatches,1);
  for kBatch = 1:nBatches
    k1 = firstFrames(kBatch);
    k2 = lastFrames(kBatch);
    vidBatch{kBatch} = vid(k1:k2);
  end
  fprintf('Generating RegionsOfInterest for %i frames\n',N);
  t=hat;
  %% GENERATE ROIs AT FRAME-BY-FRAME LEVEL
  parfor kBatch = 1:nBatches
    subT=hat;
    k1 = firstFrames(kBatch);
    roiSubBatch = generateRegionsOfInterest(vidBatch{kBatch});
    for k=1:nBatchFrames
      roiSubFrame = roiSubBatch([roiSubBatch.Frames] == k)
      set(roiSubFrame, 'Frames', [k1 - 1 + k]')
    end
    roiAtBatch{kBatch} = roiSubBatch;
    fprintf('\t\t Batch %i: generated %i ROIs \t(%0.1f seconds)\n',...
      kBatch, numel(roiSubBatch), hat-subT);
  end
  roi = cat(1, roiAtBatch{:});
  assignin('base', 'roi', roi);
  try
    rs = regionSeeds(roi);
  catch me
    keyboard
  end
  assignin('base', 'rs', rs);
  partime = hat-t;
  fprintf('\tGenerated %i ROIs in %0.1f seconds\n',numel(roi), partime);
  %   for k = 1:N
  %     roiAtFrame{k,1} = roi([roi.Frames] == k);
  %   end
  t=hat;
  %% GENERATE ROI 'GROUPS' BY FINDING SIMILAR ROIS IN EACH FRAME  
  fprintf('Evaluating %i frame batches in parallel\n', nBatches)
  for kBatch = 1:nBatches
    subT=hat;
    subRoiBatch = roiAtBatch{kBatch};
    if ~isempty(subRoiBatch)
      [mRoiBatch{kBatch}, cRoiBatch{kBatch}] = groupRois(subRoiBatch, rs);
    else
      mRoiBatch{kBatch} = RegionOfInterest.empty(0,1);
      cRoiBatch{kBatch} = RegionOfInterest.empty(0,1);
    end
    fprintf('\t\t Batch %i: Grouped %i ROIs by merging into %i, and combining into %i\t(%0.1f seconds)\n',...
      kBatch, numel(subRoiBatch), numel(mRoiBatch{kBatch}), numel(cRoiBatch{kBatch}), hat-subT);
  end
  partime = hat-t;
  fprintf('\t Completed %i batches in %0.1f seconds\n\t\t%0.1f seconds/batch\n\t\t%0.2f ms/frame\n',...
    nBatches, partime, partime/nBatches, 1000*partime/N)
  mRoi = cat(1,mRoiBatch{:});
  cRoi = cat(1,cRoiBatch{:});
catch me
  keyboard
end





function [mergedRoi, combinedRoi] = groupRois(roi,varargin)
% groups ROIs from each frame with close
firstFrame = roi(1).Frames(1);
if nargin>1
  roiSeedGroup = varargin{1};
else
  roiSeedGroup = roi([roi.Frames] == firstFrame);
end
roiAll = roi;
N = numel(roiAll);
ar.eccentricity = [roiAll.Eccentricity];
ar.area = [roiAll.Area];
ar.centroids = cat(1,roiAll.Centroid);
csThresh = 5; % (centroid-separation maximum threshold in pixels)

%% FORM GROUPS FROM NEW ROIS AND ADD SIMILAR ROIS TO EXISTING GROUPS
try
  nGroups = numel(roiSeedGroup);
  for kGroup = 1:nGroups
    roiGroups{kGroup} = roiSeedGroup(kGroup);
  end
  roiGroupPower = ones(nGroups,1);
  for kFrame = firstFrame : roi(end).Frames(end) %note: may need to sort input by frame numbers later if function to take superrois
    %     fprintf('ROI Groups: %i \tFrame: %i\n',...
    %       nGroups, kFrame);
    roiThisFrame = roi(cat(1,roi.Frames) == kFrame);
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
    %       fprintf('Identifying unique ROIs in group %i\n',kGroup)
    uObj = unique(roiGroups{kGroup});
    if numel(uObj)>1      %       fprintf('\t%i unique ROIs\n',numel(uObj));
      mroi = merge(uObj); else mroi = uObj; end
    if numel(mroi) > 1
      [~,idx] = max([mroi.fractionalOverlap(uObj)]);
      mroi = mroi(idx);
    end
    croi = combine(uObj);
    if numel(croi) > 1
      [~,idx] = min([croi.Area]);
      croi = croi(idx);
    end
    mroi = unique(mroi);
    croi = unique(croi);
    if numel(mroi)>1
      mroi = mroi(1);
    end
    if numel(croi)>1
      croi = croi(1);
    end
    if ~isempty(mroi)
      mergedRoi(kGroup) = mroi;
    end
    if ~isempty(croi)
      combinedRoi(kGroup) = croi;
    end
  end
  mergedRoi = removeEmpty(mergedRoi);
  mergedRoi = mergedRoi(:);
  combinedRoi = removeEmpty(combinedRoi);
  combinedRoi = combinedRoi(:);
catch me
  keyboard
end








% BATCHFRAMES = 250
% Batch 9: generated 909 ROIs 	(10.2 seconds)
% Batch 8: generated 1295 ROIs 	(13.4 seconds)
% Batch 1: generated 5436 ROIs 	(26.9 seconds)
% Batch 5: generated 4966 ROIs 	(25.5 seconds)
% Batch 3: generated 6307 ROIs 	(28.8 seconds)
% Batch 7: generated 6925 ROIs 	(25.6 seconds)
% Batch 6: generated 7264 ROIs 	(27.2 seconds)
% Batch 2: generated 7185 ROIs 	(32.5 seconds)
% Batch 4: generated 6790 ROIs 	(32.1 seconds)
%  VS.
% NON-PARALLEL 2047 frames
% t = 43.0873 seconds (but only 6084 rois... b/c changes made)


% parfeval
% genFcn = @(f1,f2) generateRegionsOfInterest(vid(f1:f2))
%   j(kBatch) = myCluster.createJob(genFcn, 1, {k1,k2});
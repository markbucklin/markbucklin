function [roiGroup,varargout] = reduceRegions(roi)

frameSize = roi(end).FrameSize;

%% BEGIN PARALLEL CLUSTER
% pp = gcp;
% pc = pp.Cluster;
% pj = pc.findJob;
% if ~isempty(pj)
%   cancel(pj);
% end


%% SPLIT DATA INTO BATCHES FOR PARALLEL PROCESSING
wIm = roi.weightedImage();
imreg = imregionalmin(imimposemin(imcomplement(wIm), wIm > .001));
imex = imextendedmax(wIm,.05);
% bwroi = bwmorph(imreconstruct(imextendedmax(wIm,.001), wIm>.005),'thicken');
% labroi = bwlabel(bwroi);
imws = watershed(imcomplement(imex));
imws = imws + 1;
% imfill
% imreconstruct
% imdilate
% allRois = roi;
% xlim = cat(1,roi.XLim);
% ylim = cat(1,roi.YLim);
rCent = round(cat(1,roi.Centroid));
rInd = sub2ind(frameSize, rCent(:,2), rCent(:,1));
nBatches = max(imws(:));
rBatchIdx = imws(rInd);
for kBatch = 1:nBatches
  roiBatchGroup{kBatch} = roi(rBatchIdx == kBatch);
  roiBatN(kBatch) = numel(roiBatchGroup{kBatch});
end



%% BEGIN PARALLEL REDUCTIONS (BATCHING ACROSS TIME)
%   hRedunctionFunction = @(rkeyin) reduceKeyedRegions(rkeyin);


%% GET INITIAL MEASURES AND DEFINE PROCESSING PARAMETERS
nRois = numel(roi);
roivec.eccentricity = cat(1,roi.Eccentricity);
roivec.area = cat(1,roi.Area);
roivec.centroids = cat(1,roi.Centroid);
% roivec.frames = cat(1,roi.Frames);
% frameNumbers = unique(roivec.frames);
% nFrames = numel(frameNumbers);
for kRoi = 1:nRois
  roivec.nIdx(kRoi) = numel(roi(kRoi).PixelIdxList);
  %   roi(kRoi).Idx = kRoi;
end


%% CONSTRUCT 'KEYS' REPRESENTING EACH PIXEL IN THE IMAGE OCCUPIED BY AN ROI
idx.roipix = cat(1,roi.PixelIdxList);
roiFirstIdxIdx = [1 ; cumsum(roivec.area)+1];
r1 = roiFirstIdxIdx;
r2 = [ r1(2:end)-1 ; numel(idx.roipix)];
for kRoi = 1:numel(r1)
  idx.roimap(r1(kRoi):r2(kRoi),1) = kRoi;
end

%% STILL NEED TO ASSIGN KEYS TO EACH ROI... OR VICE-VERSA....
ovlpMinN = 75;
similarMinN = 25;
ovlproi.idx = cell(nRois,1);
ovlproi.n = NaN(nRois,1);
allSimRoi = [];
roiGroup = RegionOfInterest.empty(0,1);
tic
for kRoi=1:numel(roi)
  % (alternatively, pick rois from distributed regions in parallel)
  %
  %     thisRoi = roi(kRoi);
  %     thisCentroid = round(thisRoi.Centroid);
  if ~ismember(kRoi, allSimRoi)
    thisCentroid = round(roivec.centroids(kRoi,:));
    thisIdx = sub2ind(frameSize, thisCentroid(2), thisCentroid(1));
    ovlpRoiIdx = idx.roimap(idx.roipix == thisIdx);
    ovlpRoiN = numel(ovlpRoiIdx);
    if ovlpRoiN >= ovlpMinN;
      ovlpRoi = roi(ovlpRoiIdx);
      simRoi = mostSimilar(ovlpRoi);
      if numel(simRoi) >= similarMinN
        allSimRoi = cat(1, allSimRoi, cat(1,simRoi.Idx));
        newRoiGroup = merge(simRoi);
        roiGroup = cat(1, roiGroup, newRoiGroup);
        fprintf('New ROI group with %i sub-regions\n',numel(simRoi))
      end
    end
    ovlproi.n(kRoi) = ovlpRoiN;
    ovlproi.idx{kRoi} = ovlpRoiIdx;
  end
end
toc

if nargout > 1
  varargout{1} = ovlproi;
end

%%

%   k = 6010;
%   obj = roi(ovlproi.idx{k});
%   isSim = sufficientlySimilar(obj);
%   [~,idx] = max(sum(isSim));
%   simGroup = obj(isSim(idx,:));
%   show(simGroup)







%%
%
%   nRoiAtKey = zeros(numel(allKeys),1);
%   tic
%   parfor kKey=1:numel(allKeys)
%     roisWithKey = roi(idx.roimap(idx.roipix(keyRdx == allKeys(kKey))));
%     nRoiAtKey(kKey) = numel(roisWithKey);
%     %     addKey(roisWithKey, kKey);
%     %     roiByKey{kKey} = roisWithKey;
%
%   end
%   toc
%
%
%   %%
%
%
%
%
%
%
%
%
%
%
%   kKey = 1;
%   rk=false(size(roi));
%   thisKey = allKeys(kKey);
%   tic
%   for kRoi = 1:numel(roi) % .32 s for 33057 rois
%     rk(kRoi) = any(roi(kRoi).PixelIdxList == thisKey);
%   end
%   toc
%
%
%   %   roisAtFrame = cell(nFrames,1);
%   %   for kFrame = 1:nFrames
%   %     fn = frameNumbers(kFrame);
%   %     roisAtFrame{kFrame} = roi(roivec.frames == fn);
%   %   end
%
%   %% SPLIT DATA INTO (KEYED) BATCHES FOR PARALLEL PROCESSING
%   %   k1k2ratio = 50; % up to 127?
%   %   nKeysIn = floor(nFrames/50);
%   %   roisAtKeyIn = cell(nKeysIn,1);
%   %   for kFrame = 1:nKeysIn
%   %     kout1 = (kFrame-1)*k1k2ratio + 1;
%   %     kout2 = kout1 + k1k2ratio - 1;
%   %     RK = roisAtFrame{kout1:kout2};
%   %     set(RK, 'Key2', kFrame);
%   %     roisAtKeyIn{kFrame} = roisAtFrame(kout1:kout2);
%   %   end
%
%   %% BEGIN PARALLEL CLUSTER
%   pp = gcp;
%   pc = pp.Cluster;
%   pj = pc.findJob;
%   if ~isempty(pj)
%     cancel(pj);
%   end
%
%   %% BEGIN PARALLEL REDUCTIONS (BATCHING ACROSS TIME)
%   hRedunctionFunction = @(rkeyin) reduceKeyedRegions(rkeyin);
%
%
%
%
%
%
%
%
%
%   %% GENERATE ROI 'GROUPS' BY FINDING SIMILAR ROIS IN EACH FRAME
%   %   fprintf('Evaluating %i frame batches in parallel\n', nBatches),t=hat;
%   %   for kBatch = 1:nBatches
%   %     subT=hat;
%   %     subRoiBatch = roiAtBatch{kBatch};
%   %     if ~isempty(subRoiBatch)
%   %       [mRoiBatch{kBatch}, cRoiBatch{kBatch}] = groupRois(subRoiBatch, rs);
%   %     else
%   %       mRoiBatch{kBatch} = RegionOfInterest.empty(0,1);
%   %       cRoiBatch{kBatch} = RegionOfInterest.empty(0,1);
%   %     end
%   %     fprintf('\t\t Batch %i: Grouped %i ROIs by merging into %i, and combining into %i\t(%0.1f seconds)\n',...
%   %       kBatch, numel(subRoiBatch), numel(mRoiBatch{kBatch}), numel(cRoiBatch{kBatch}), hat-subT);
%   %   end
%   %   partime = hat-t;
%   %   fprintf('\t Completed %i batches in %0.1f seconds\n\t\t%0.1f seconds/batch\n\t\t%0.2f ms/frame\n',...
%   %     nBatches, partime, partime/nBatches, 1000*partime/nRois)
%   %   mRoi = cat(1,mRoiBatch{:});
%   %   cRoi = cat(1,cRoiBatch{:});
% catch me
%   keyboard
% end
%
%
%
%
%
% function [mergedRoi, combinedRoi] = reduceKeyedRegions(roi,varargin)
% % groups ROIs from each frame with close
% firstFrame = roi(1).Frames(1);
% if nargin>1
%   roiSeedGroup = varargin{1};
% else
%   roiSeedGroup = roi([roi.Frames] == firstFrame);
% end
% roiAll = roi;
% N = numel(roiAll);
% ar.eccentricity = [roiAll.Eccentricity];
% ar.area = [roiAll.Area];
% ar.centroids = cat(1,roiAll.Centroid);
% csThresh = 5; % (centroid-separation maximum threshold in pixels)
%
% %% FORM GROUPS FROM NEW ROIS AND ADD SIMILAR ROIS TO EXISTING GROUPS
% try
%   nGroups = numel(roiSeedGroup);
%   for kGroup = 1:nGroups
%     roiGroups{kGroup} = roiSeedGroup(kGroup);
%   end
%   roiGroupPower = ones(nGroups,1);
%   for kFrame = firstFrame : roi(end).Frames(end) %note: may need to sort input by frame numbers later if function to take superrois
%     %     fprintf('ROI Groups: %i \tFrame: %i\n',...
%     %       nGroups, kFrame);
%     roiThisFrame = roi([roi.Frames] == kFrame);
%     nPrevGroups = nGroups;
%     % COMPARE MOST RECENT ROI FROM EACH EXISTING GROUP TO CURRENT ROIs
%     for kGroup = 1:nPrevGroups
%       groupedSet = roiGroups{kGroup};
%       groupedRoi = groupedSet(end);
%       csep = groupedRoi.centroidSeparation(roiThisFrame);
%       dUnder = csep<csThresh;
%       % ADD MOST SIMILAR ROI TO EXISTING GROUP (IF UNDER CENTROID-SEPARATION THRESHOLD)
%       if any(dUnder)
%         [~,idx] = min(csep(:));
%         similarRoi = roiThisFrame(idx);
%         roiGroups{kGroup} = cat(1, groupedSet(:), similarRoi);
%         roiGroupPower(kGroup) = roiGroupPower(kGroup) + 1;
%         roiThisFrame = roiThisFrame(~dUnder);
%       end
%     end
%     % FORM NEW SINGLETON GROUPS FROM ANY REMAINING/UNMATCHED ROIs
%     if numel(roiThisFrame) >= 1
%       nGroups = nPrevGroups + numel(roiThisFrame);
%       newGroupIdx = nPrevGroups+1 : nGroups;
%       for kNew = 1:numel(roiThisFrame)
%         idx = newGroupIdx(kNew);
%         roiGroups{idx} = roiThisFrame(kNew);
%         roiGroupPower(idx) = 1;
%       end
%     end
%   end
%
%
%   %% MERGE & COMBINE EACH GROUP OF REGIONS INTO A 'SUPER-REGION'
%   for kGroup=1:nGroups
%     %       fprintf('Identifying unique ROIs in group %i\n',kGroup)
%     uObj = unique(roiGroups{kGroup});
%     if numel(uObj)>1      %       fprintf('\t%i unique ROIs\n',numel(uObj));
%       mroi = merge(uObj); else mroi = uObj; end
%     if numel(mroi) > 1
%       [~,idx] = max([mroi.fractionalOverlap(uObj)]);
%       mroi = mroi(idx);
%     end
%     croi = combine(uObj);
%     if numel(croi) > 1
%       [~,idx] = min([croi.Area]);
%       croi = croi(idx);
%     end
%     mroi = unique(mroi);
%     croi = unique(croi);
%     if numel(mroi)>1
%       mroi = mroi(1);
%     end
%     if numel(croi)>1
%       croi = croi(1);
%     end
%     if ~isempty(mroi)
%       mergedRoi(kGroup) = mroi;
%     end
%     if ~isempty(croi)
%       combinedRoi(kGroup) = croi;
%     end
%   end
%   mergedRoi = removeEmpty(mergedRoi);
%   mergedRoi = mergedRoi(:);
%   combinedRoi = removeEmpty(combinedRoi);
%   combinedRoi = combinedRoi(:);
% catch me
%   keyboard
% end
%
%
%
%
%
%
%
%
% % BATCHFRAMES = 250
% % Batch 9: generated 909 ROIs 	(10.2 seconds)
% % Batch 8: generated 1295 ROIs 	(13.4 seconds)
% % Batch 1: generated 5436 ROIs 	(26.9 seconds)
% % Batch 5: generated 4966 ROIs 	(25.5 seconds)
% % Batch 3: generated 6307 ROIs 	(28.8 seconds)
% % Batch 7: generated 6925 ROIs 	(25.6 seconds)
% % Batch 6: generated 7264 ROIs 	(27.2 seconds)
% % Batch 2: generated 7185 ROIs 	(32.5 seconds)
% % Batch 4: generated 6790 ROIs 	(32.1 seconds)
% %  VS.
% % NON-PARALLEL 2047 frames
% % t = 43.0873 seconds (but only 6084 rois... b/c changes made)
%
% % myCluster = parcluster('local');
% % parfeval
% % genFcn = @(f1,f2) generateRegionsOfInterest(vid(f1:f2))
% %   j(kBatch) = myCluster.createJob(genFcn, 1, {k1,k2});
%
%
%
%
%
% % parfor kFrame = 1:numel(frameNumbers)
% %   fnum = frameNumbers(kFrame);
% %   roifn = roi(roiFrameIdx == fnum);
% %   roipost = roi(roiFrameIdx > fnum);
% %   ovlp = overlaps(roifn, roipost);
% %   for kRoi = 1:numel(roifn)
% %     roiPostOvlp = roipost(ovlp(kRoi,:)');
% %     roifn(kRoi).OverlappingRegion = roiPostOvlp(:);
% %     % TODO: add roifn to overlapping regions of roipostovlp
% %   end
% % end

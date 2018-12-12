function roiSeed = regionSeeds(roi)

%% DEFINE PARAMETERS FOR SEED SELECTION
meanRelativeMinIncidence = .20;
seedMinArea = 20;
maxEccentricity = .85;
maxPerimOverSqArea = 8;

%% GET INCIDENCE FROM ROI MASKS TO DETERMINE DECENT GROUPS
N = numel(roi);
dk = 255;
inds = 1:dk:N;
parfor k=1:numel(inds)
  k1 = inds(k);
  k2 = min(N, inds(k)+dk-1);
  rm = cat(3,roi(k1:k2).Mask);
  roiSum(:,:,k) = sum(uint8(rm),3);
end
roiSum = sum(uint32(roiSum),3);
rsMean = mean(roiSum(roiSum>=1));
roiSum = gpuArray(roiSum);

%% FIND CIRCULAR SEED REGIONS FROM ROI INCIDENCE MATRIX
% [centers,radii] = imfindcircles(roiSum,[5 20], 'Sensitivity', .95);
% h = handle(viscircles(centers, radii, 'DrawBackgroundCircle',false));
% set(gca,'Position',[0.01 0.01 .98 .98]);

%% watershed
% im = gather(roiSum);
% im = im2uint8(mat2gray(im));
% imshow(im)
% im = imtophat(im, strel('disk', 8, 8));
% im = imcomplement(im);
% for th = 150:2:254, imshow(imimposemin(imcomplement(imimposemin(imcomplement(im), im>th)), im<th)); pause, end

%% BINARY OPS ON ROI INCIDENCE
rssStep = rsMean*meanRelativeMinIncidence;
bwx = false(size(roiSum));
roiSeed = [];
clf;
for k = 1:40
  th1 = k*rssStep;
  th2 = k*rssStep + rssStep;
  %   bw = (roiSum > th2) - (roiSum > th1);
  bw = xor( (roiSum > th2) , (roiSum > th1) );
  bw = bwmorph(bwmorph(bwmorph( bw, 'open'), 'shrink'), 'majority');
  %   imagesc(bw)
  c = regionprops(gather(bw),...
    'Centroid', 'BoundingBox','Area',...
    'Eccentricity', 'PixelIdxList', 'Perimeter');
  c = c([c.Area] > seedMinArea);
  c = c([c.Eccentricity] < maxEccentricity);
  c = c([c.Perimeter]./sqrt([c.Area]) < maxPerimOverSqArea); 
  if numel(c) > 0
    rsnew = RegionOfInterest(c,...
    'FrameSize',size(roiSum));
    if isempty(roiSeed)
      roiSeed = rsnew;
      %       show(roiSeed);
    else
      try
        for krs = 1:numel(rsnew)
          ov = rsnew(krs).overlaps(roiSeed);
          if any(ov)
            bwov = and(rsnew(krs).Mask, ~logical(sum(cat(3,roiSeed(ov).Mask),3)));
            rsov = RegionOfInterest(bwov,...
              'FrameSize',size(roiSum));
            for kov = 1:numel(rsov)
              if (rsov(kov).Area > seedMinArea) ...
                  && (rsov(kov).Eccentricity < maxEccentricity) ...
                  && (rsov(kov).Perimeter/sqrt(rsov(kov).Area) < maxPerimOverSqArea)                
                roiSeed = cat(1,roiSeed(:), rsov(kov));
                %               show(rsov(kov));
              end
            end
          else
            roiSeed = cat(1,roiSeed(:), rsnew(krs));
            %           show(rsnew(krs));
          end
        end
      catch me
        keyboard
      end
    end
  end
  %   bwl = zeros(size(rss));
  %   for krs = 1:numel(rs)
  %     bwl(rs(krs).PixelIdxList) = krs;
  %   end
  %   imagesc(bwl)
  %   [centers,radii] = imfindcircles(rss,[5 20], 'Sensitivity', .95);
  %   h = handle(viscircles(centers, radii, 'DrawBackgroundCircle',false));
  %   set(gca,'Position',[0.01 0.01 .98 .98]);
  %   show(rs)
  fprintf('Iteration: %i\t NumSeeds: %i\n',k,numel(roiSeed));
  %   show(rs)
  %   pause
end
% try
%   showfcn = @(~,~)dysfunctionalShow(rs);
%   t = timer(...
%     'ExecutionMode','singleShot',...
%     'TasksToExecute',1,...
%     'StartDelay', 1,...
%     'TimerFcn',showfcn);
%   start(t)
% catch me
%   disp(me.message)
% end






%   bwr = any(cat(3, rsnew.Mask),

%   bwx = or(bw, bwx);
%     bwc = bwconncomp(gather(bw));
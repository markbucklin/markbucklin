
%%
roiAll = roi;
% roiBig = roi(ar.area>1000);
% roiSmall = roi(ar.area<=1000);
N = numel(roiAll);
ar.eccentricity = [roiAll.Eccentricity];
ar.area = [roiAll.Area];
ar.centroids = cat(1,roiAll.Centroid);


%%
waitfor(msgbox('Trace a few cells to give an approximation of the target cell size'));
vidSample = getVidSample(vid);
sampleImage = mat2gray( range( cat(3, vidSample.cdata), 3));
imshow(sampleImage);
% 	imshow(mat2gray( var(single(cat(3,vidSample.cdata)),1,3)));
doAnotherRoi = 'yes';
nRoi = 0;
while(strcmpi(doAnotherRoi,'yes'))
  nRoi = nRoi +1;
  hRoi(nRoi) = impoly(gca);
  doAnotherRoi = questdlg('Trace Another Cell?');
end
for k = 1:numel(hRoi)
  cMask = hRoi(k).createMask;
  maskArea(k) = sum(cMask(:));
  cellMask(:,:,k) = cMask;
end
% if numel(hRoi) > 3
%   for k=1:3
%   bgMask(:,:,k) = sum(cellMask(:,:,k:3:end),3);
%   end
% else
%   for k=1:3
% 	 bgMask(:,:,k) = cellMask(:,:,min(k,size(cellMask,3)));
%   end
% end
% hold on
% imshow(bgMask)
bgMask = sum(cellMask,3);
imshowpair(sampleImage, bgMask);
drawnow

crit.maxArea = max(maskArea) + std(maskArea)/2;
crit.minArea = min(maskArea) - std(maskArea)/2;
tooSmall = ar.area < crit.minArea;
tooBig = ar.area > crit.maxArea;
roiSmall = roi(tooSmall);
roiBig = roi(tooBig);
roiJustRight = roi( ~(tooSmall | tooBig));
roi = roiJustRight;

%%
roiThisFrame = roi([roi.Frames] == 1);
nGroups = numel(roiThisFrame);
for kGroup = 1:nGroups
  roiGroups(1,kGroup) = roiThisFrame(kGroup);
end
for kFrame = 2:roi(end).Frames
  fprintf('ROI Groups: %i \tFrame: %i\n',...
		nGroups, kFrame);
  roiThisFrame = roi([roi.Frames] == kFrame);
  nPrevGroups = nGroups;
  % Compare the most recent ROI from each existing group to all ROIs in current frame
  for kGroup = 1:nPrevGroups	 
	 groupedRoi = roiGroups(kFrame-1, kGroup);
	 bb = groupedRoi.isInBoundingBox(roiThisFrame);
	 % If there's any overlap, check whether it's bisubstantial
	 if any(bb)
		similarRoi = roiThisFrame(find(bb,1,'first'));	
		[thisoverall, alloverthis] = groupedRoi.fractionalOverlap(similarRoi);
		% If overlap is bisubstantial, add ROI from current frame to that group
		if (thisoverall > .8) & (alloverthis > .8)
		  roiGroups(kFrame,kGroup) = similarRoi;
		  roiThisFrame = roiThisFrame(~bb);
		else
		  roiGroups(kFrame,kGroup) = groupedRoi;
		end
	 else
		roiGroups(kFrame,kGroup) = groupedRoi;		
	 end
  end
  % Add any remaining/unmatched ROIs as new groups
  if numel(roiThisFrame) >= 1
	 nGroups = nPrevGroups + numel(roiThisFrame);
	 roiGroups(kFrame, nPrevGroups+1 : nGroups) = roiThisFrame(:)';
  end
end


%%
while (numel(roi) > .1*N)
  thisRoi = roi(1);
  [thisoverall, alloverthis] = thisRoi.fractionalOverlap(roi);
  %    plot([thisoverall(:), alloverthis(:)])
  criteria = (thisoverall > .8) & (alloverthis > .8);
  nOverlapping = sum(double(criteria));
  if  nOverlapping >= 10
	 nGroups = nGroups + 1;
	 mutualRoi = roi(criteria);
	 %       show(mutualRoi);
	 roi = roi(~criteria);
	 superRoi(nGroups) = merge(mutualRoi);
	 fprintf('New merged ROI with %i SubROIs \t%i groups \t%i remaining\n',...
		nOverlapping, nGroups, numel(roi));
  end
end

%%
hTitle = title(sprintf('%i',k));
gsize = cellfun(@(grp)numel(grp), roiGroups);
roiGroups = roiGroups(gsize>2);
for k=1:numel(roiGroups)
  rg = roiGroups{k};
  show(rg)
  hTitle.String = sprintf('Group: %i  (%i ROIs)',k,numel(rg));
  drawnow
  pause(.01)
end


% maskAll = cat(3, roiAll.Mask);
% maskSum = sum(uint16(maskAll), 3);
% plot([roi.Eccentricity])
% plot([roi.Area])

% csbox = zeros(numel(roi),'uint16');
% h=waitbar(0,'Building centroid separation matrix');
% for k=1:(N-1)
%   waitbar(k/N, h);
%   csbox(k, k:end) = roi(k).centroidSeparation(roi(k:end));
% end
% delete(h)















%%
stat = getVidStats(vid);

%%
imshow(stat.Range)
[centers,radii] = imfindcircles(stat.Max,[6 18], 'Sensitivity', .9);
h = handle(viscircles(centers, radii,...
  'DrawBackgroundCircle',false,...
  'LineWidth',1,...
  'EdgeColor','m'...
  ));
%%
cellMask = circleCenters2Mask(centers, radii, size(vid(1).cdata));










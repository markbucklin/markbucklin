% potentially useful for finding cells

vidVar.preCorrection = var(im2double(cat(3,vid(1:10:end).cdata)),1,3);
% I = vid(1).cdata;
I = imadjust(vidVar.preCorrection);

%% GET RANGE OF TARGET CELL SIZES FROM USER
hImage = imagesc(I);
waitfor(msgbox('select the smallest cell'))
ip = imellipse(gca);
cellmask = ip.createMask;
delete(ip);
cellMinArea = sum(cellmask(:));
waitfor(msgbox('select the largest cell'))
ip = imellipse(gca);
cellmask = ip.createMask;
delete(ip)
cellMaxArea = sum(cellmask(:));
close(gcf);

%% Maximally Stable Extremal Regions (MSER) algorithm to find regions.
regions = detectMSERFeatures(I,...
	'ThresholdDelta',8,...
	'RegionAreaRange',[20 cellMaxArea*4],... %round([.75*cellMinArea 1.25*cellMaxArea]),...
	'MaxAreaVariation',40)
% cellMaxArea/cellMinArea
% 'ROI'

%% detectSURFFeatures uses Speeded-Up Robust Features (SURF) algorithm to find blob features.
 points = detectSURFFeatures(I,...
	 'MetricThreshold',100,...
	 'NumOctaves',3,...
	 'NumScaleLevels',6)


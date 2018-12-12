
maxim = max(single(cat(3,dvid.cdata)),[],3);
minim = min(single(cat(3,dvid.cdata)),[],3);

%% potentially useful for finding cells

vidVar.wholesamp10 = var(im2double(cat(3,dvid(1:10:end).cdata)),1,3);
% I = vid(1).cdata;
I = imadjust(vidVar.wholesamp10);

%% sum of second variance
fps = 20;
firstFrame = 1:fps:numel(vid);
nFrames = numel(vid);
bySecond = zeros([size(I) numel(firstFrame)]);
parfor k = 1:numel(firstFrame)
	f1 = firstFrame(k);
	f2 = min(f1+fps-1,nFrames);
	bySecond(:,:,k) = var(im2double(cat(3,vid(f1:f2).cdata)),1,3);
end
	


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











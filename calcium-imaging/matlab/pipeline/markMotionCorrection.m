
%% LOAD IMAGES
[fname,fpath] = uigetfile('.tif','choose a tif file');
filename = fullfile(fpath,fname);
info = imfinfo(filename);
nframes = numel(info);
framesize = [info(1).Height info(1).Width];
vid = zeros([framesize nframes],'uint16');
for k=1:nframes
	vid(:,:,k) = imread(filename,k);
end

%%
cmap = zeros(256,3);
cmap(:,2) = linspace(0,1,256);

%%
firstFrame = 1;
lastFrame = size(vid,3);
subPixNum = 100;
refImage = double(vid(:,:,lastFrame));
refImFourier = fft2(refImage);
regOut = struct.empty(lastFrame-firstFrame+1,0);


%%
for k = firstFrame:lastFrame
	unshiftedImage = double(vid(:,:,k));
	[nRows,nCols] = size(unshiftedImage);
	[output, shiftedImFourier] = dftregistration(...
		refImFourier,...
		fft2(unshiftedImage),...
		subPixNum);
	regOut(k).rmsError = output(1);
	regOut(k).globalPhaseDiff = output(2);
	regOut(k).rowShift = output(3);
	regOut(k).columnShift = output(4);
	regOut(k).regImage = abs(ifft2(shiftedImFourier));
% 	xq = (1:1/5:nCols) + output(4);
% 	yq = (1:1/5:nRows) + output(3);
% 	[Xq,Yq] = meshgrid(xq,yq);
% 	regOut(k).shiftImage = interp2(unshiftedImage,Xq,Yq,'cubic');
end

%% MOVING AVERAGE
smallWinSize = 5;
tpad = floor(smallWinSize/2);
for k = firstFrame:lastFrame
	regOut(k).timeFilteredImage = mean(cat(3,regOut(max(1,k-tpad):min(lastFrame,k+tpad)).regImage),3);
end
largeWinSize = 300;
tpad = floor(largeWinSize/2);
roi = roipoly(regOut(1).timeFilteredImage);

for k = firstFrame:lastFrame
	regOut(k).slowBaselineImage = mean(cat(3,regOut(max(1,k-tpad):min(lastFrame,k+tpad)).regImage),3);
	regOut(k).slowMaxImage = max(cat(3,regOut(max(1,k-tpad):min(lastFrame,k+tpad)).regImage),[],3);
	rmask = regOut(k).timeFilteredImage(roi);
	regOut(k).tfIntensityImage = mat2gray(...
		regOut(k).timeFilteredImage,...
		[min(rmask(:)) max(rmask(:))]);
end
baseLineChange = cat(3,regOut(:).regImage) - cat(3,regOut(:).slowBaselineImage);
for k = firstFrame:lastFrame
	regOut(k).slowIntensityBaseline = mat2gray(...
		regOut(k).slowBaselineImage,...
		[min(rmask(:)) max(rmask(:))]);
	regOut(k).slowIntensityMax = mat2gray(...
		regOut(k).slowMaxImage,...
		[min(rmask(:)) max(rmask(:))]);
end


% foverf = cat(3,regOut(:).timeFilteredImage)./cat(3,regOut(:).slowBaselineImage);

% ianimate(foverf,'fps',30)
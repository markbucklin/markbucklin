function [data, pre] = normalizeDataMinSubtract(data, pre)
fprintf('Normalizing Fluorescence Signal \n')
% assignin('base','dataprenorm',data);
fprintf('\t Input MINIMUM: %i\n',min(data(:)))
fprintf('\t Input MAXIMUM: %i\n',max(data(:)))
fprintf('\t Input RANGE: %i\n',range(data(:)))
fprintf('\t Input MEAN: %i\n',mean(data(:)))

if nargin < 2
   pre.fmin = min(data,[],3);
   pre.fmean = single(mean(data,3));
   pre.fmax = max(data,[],3);
   pre.minval = min(data(:));
   % pre.fstd = std(single(data),1,3);
   % mfstd = mean(pre.fstd(pre.fstd > median(pre.fstd(:))));
   % pre.scaleval = 65535/mean(pre.fmax(pre.fmax > 2*mean2(pre.fmax)));
end
% fkmean = single(mean(mean(data,1),2));
% difscale = (65535 - fkmean/2) ./ single(getNearMax(data));
N = size(data,3);%TODO:hardcoded
data = bsxfun( @minus, data+1024, imclose(pre.fmin, strel('disk',5)));%TODO:hardcoded
fprintf('\t Post-Min-Subtracted MINIMUM: %i\n',min(data(:)))
fprintf('\t Post-Min-Subtracted MAXIMUM: %i\n',max(data(:)))
fprintf('\t Post-Min-Subtracted RANGE: %i\n',range(data(:)))
fprintf('\t Post-Min-Subtracted MEAN: %i\n',mean(data(:)))

% SEPARATE ACTIVE CELLULAR AREAS FROM BACKGROUND (NEUROPIL)
if nargin < 2
   activityImage = imfilter(range(data,3), fspecial('average',101), 'replicate');%TODO:hardcoded
   pre.npMask = double(activityImage) < mean2(activityImage);
   pre.npPixNum = sum(pre.npMask(:));
   pre.cellMask = ~pre.npMask;
   pre.cellPixNum = sum(pre.cellMask(:));
end
pre.npBaseline = sum(sum(bsxfun(@times, data, cast(pre.npMask,'like',data)), 1), 2) ./ pre.npPixNum; %average of pixels in mask
pre.cellBaseline = sum(sum(bsxfun(@times, data, cast(pre.cellMask,'like',data)), 1), 2) ./ pre.cellPixNum;

% % REMOVE BASELINE SHIFTS BETWEEN FRAMES (TODO: untested, maybe move to subtractBaseline)
% data = cast( exp( bsxfun(@minus,...
%    log(single(data)+1) + log(pre.baselineOffset+1) ,...
%    log(single(npBaseline)+1))) - 1, 'like', data) ;
% fprintf('\t Post-Baseline-Removal range: %i\n',range(data(:)))
if nargin < 2
   pre.baselineOffset = median(pre.npBaseline);
end
data = cast( bsxfun(@minus,...
   single(data), single(pre.npBaseline)) + pre.baselineOffset, ...
   'like', data);


% SCALE TO FULL RANGE OF INPUT (UINT16)
if nargin < 2
   pre.scaleval = 65535/double(1.1*getNearMax(data));%TODO:hardcoded
end
data = data*pre.scaleval;

fprintf('\t Output MINIMUM: %i\n',min(data(:)))
fprintf('\t Output MAXIMUM: %i\n',max(data(:)))
fprintf('\t Output RANGE: %i\n',range(data(:)))
fprintf('\t Output MEAN: %i\n',mean(data(:)))

% if nargin >= 2
%    lastFrame = pre.connectingFrame(npMask);
%    firstFrameMedfilt = median(data(:,:,1:8), 3);
%    firstFrame = data(:,:,1);
%    firstFrame = firstFrame(npMask);
%    interFileDif = single(firstFrame) - single(lastFrame);
%    %    fileRange = range(data,3);
%    %    baselineShift = double(mode(interFileDif(fileRange < median(fileRange(:)))));
%    baselineShift = round(mean(interFileDif(:)));
%    fprintf('\t->Applying baseline-shift: %3.3g\n',-baselineShift)
%    data = data - cast(baselineShift,'like',data);
% end
% pre.connectingFrame = data(:,:,end);
% pre.connectingFrameMedfilt = median(data(:,:,end-7:end), 3);

end
function data = subtractBaseline(data)

% sdata = double(data);

% SUBTRACT RESULTING BASELINE THAT STILL EXISTS IN NEUROPIL
activityImage = imfilter(range(data,3), fspecial('average',201), 'replicate');
npMask = double(activityImage) < mean2(activityImage);
npPixNum = sum(npMask(:));
% npIdx = find(npMask);
npBaseline = sum(sum(bsxfun(@times, double(data), npMask), 1), 2) ./ npPixNum; %average of pixels in mask
% npBaseline = npBaseline(:);
data = uint16(bsxfun(@minus, data, uint16(npBaseline)));
% data = uint16(reshape(transpose(bsxfun(@minus, sdata, npBaseline)), npix, npix, []));
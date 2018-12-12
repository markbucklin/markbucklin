function writeVidStruct2CompositeMp4(vid, varargin)
if nargin > 1
   filename = varargin{1};
else
   [filename, filedir] = uiputfile('*.mp4');
   filename = fullfile(filedir,filename);
end
fps = 20;



N = numel(vid);
if ~isa(vid(1).cdata, 'uint8')
   vid = vidStruct2uint8(vid);
end
stat = getVidStats(vid);

% ch.blue = uint8( .5*(double(stat.Max)-stat.Mean));
keyboard
ch.blue = vidStruct2uint8(vc.postalignment);
ch.green = vc.pretempsmooth;
ch.red = vc.tempsmoothed;


rgbArray(:,:,3,:) = cat(4, ch.blue.cdata);
rgbArray(:,:,2,:) = cat(4, ch.green.cdata);
rgbArray(:,:,1,:) = cat(4, ch.red.cdata);

% rgbArray(:,:,3,:) = repmat(ch.blue,[1 1 1 N]);
% vidTS = tempSmoothVidStruct(vid, fps);
% rgbArray(:,:,3,:) = repmat(imcomplement(uint8(stat.Mean)),[1 1 1 N]);
% rgbArray(:,:,3,:) = uint8( cat(4, bwvid.bwFallingEdge));
% rgbArray = rgbArray*180;
% greenMultiplier = uint8(floor(0.5*255/mean(stat.Range(:))));
% gdiff = bsxfun(@minus, cat(4, vid.cdata), stat.Min);
% rgbArray(:,:,2,:) = gdiff .* greenMultiplier;

% SEPARATE CELLS FROM VESSELS
% [centers,radii] = imfindcircles(stat.Max,[6 25], 'Sensitivity', .9);
% cellMask = circleCenters2Mask(centers, radii, size(vid(1).cdata));
% vesselMask = bwareaopen(edge(stat.Max,'sobel'),12);
% vesselMask(imdilate(cellMask, strel('disk',4,4))) = false;
% vesselMask = bwareaopen(imfill(imdilate(vesselMask, strel('disk', 6, 4)),'holes'), 450);
% rgbArray(:,:,1,:) = repmat(30.*uint8(vesselMask), [1 1 1 N]);
% imshow(vesselMask)
% keyboard
% ch.red = uint8(stat.Mean - double(stat.Min));
% rgbArray(:,:,1,:) = repmat(ch.red,[1 1 1 N]);


profile = 'MPEG-4';
writerObj = VideoWriter(filename,profile);
writerObj.FrameRate = fps;
writerObj.Quality = 65;
open(writerObj)
writeVideo(writerObj, rgbArray)
close(writerObj)

function writeRgbArray2Mp4(rgbArray,varargin)

fps = 20;

% N = numel(vid)
% rgbArray(:,:,1,:) = uint8( cat(4, bwvid.bwRisingEdge));
% rgbArray(:,:,3,:) = uint8( cat(4, bwvid.bwFallingEdge));
% rgbArray = rgbArray*180;
% rgbArray(:,:,2,:) = cat(4, vid(:).cdata);


if nargin > 1
   filename = varargin{1};
else
   [filename, filedir] = uiputfile('*.mp4');
   filename = fullfile(filedir,filename);
end
profile = 'MPEG-4';
writerObj = VideoWriter(filename,profile);
writerObj.FrameRate = fps;
writerObj.Quality = 100;
open(writerObj)
writeVideo(writerObj, rgbArray)
close(writerObj)

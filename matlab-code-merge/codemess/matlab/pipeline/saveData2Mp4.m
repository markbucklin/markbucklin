function saveData2Mp4(data,varargin)

fps = 24;

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

% if ndims(data) < 4 || size(data,3) > 3
if size(data,3) ~= 3
	[numRows, numCols, numFrames, numChannels] = size(data);
	switch numChannels
		case 1
			data = repmat(reshape(data, numRows, numCols, 1, numFrames), 1, 1, 3, 1);
		case 2
			data = permute(data, [1 2 4 3]);
			data = cat( 3, data, data(:,:,1,:));
		case 3
			data = permute(data, [1 2 4 3]);
	end
	
	
	% 	 nframes = size(data,3);
	% 	 n = nframes - rem(nframes,3);
	%    data = reshape(data(:,:,1:n),[sz(1), sz(2), 3, n/3]);
	
	
	% 	 %    data = permute(shiftdim( data, -1), [2 3 1 4]);
end


profile = 'MPEG-4';
writerObj = VideoWriter(filename,profile);
writerObj.FrameRate = fps;
writerObj.Quality = 90;
open(writerObj)
writeVideo(writerObj, data)
close(writerObj)




% OLD VERSION
% 
% function saveData2Mp4(data,varargin)
% 
% fps = 20;
% sz = size(data);
% % N = numel(vid)
% % rgbArray(:,:,1,:) = uint8( cat(4, bwvid.bwRisingEdge));
% % rgbArray(:,:,3,:) = uint8( cat(4, bwvid.bwFallingEdge));
% % rgbArray = rgbArray*180;
% % rgbArray(:,:,2,:) = cat(4, vid(:).cdata);
% 
% 
% if nargin > 1
%    filename = varargin{1};
% else
%    [filename, filedir] = uiputfile('*.mp4');
%    filename = fullfile(filedir,filename);
% end
% profile = 'MPEG-4';
% writerObj = VideoWriter(filename,profile);
% writerObj.FrameRate = fps;
% writerObj.Quality = 90;
% open(writerObj)
% 
% if ndims(data) < 4 || size(data,3) > 3
%    nframes = size(data,3);
%    n = nframes - rem(nframes,3);
%    data = reshape(data(:,:,1:n),[sz(1), sz(2), 3, n/3]);
%    %    data = permute(shiftdim( data, -1), [2 3 1 4]);
% end
% 
% writeVideo(writerObj, data)
% close(writerObj)

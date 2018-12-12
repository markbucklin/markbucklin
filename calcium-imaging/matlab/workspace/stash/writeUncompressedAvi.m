function writeUncompressedAvi(data,vidFileName)

if nargin < 2
    [fname,dirname] = uiputfile('*.avi');
    vidFileName = fullfile(dirname,fname);
end

fps = 60;
vidProfile = 'Uncompressed AVI';
vidSetting = {'FrameRate', fps};

% Build Video-Writer Object for Video Output
avi = VideoWriter( vidFileName, vidProfile);

set(avi, vidSetting{:});
closer = onCleanup(@()close(avi) );
open(avi);



writeVideo(avi, data);


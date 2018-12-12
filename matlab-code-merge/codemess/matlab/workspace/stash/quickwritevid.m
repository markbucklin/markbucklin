
%%
TL = scicadelic.TiffStackLoader;
TL.FrameInfoOutputPort = true;
TL.FramesPerStep = 4;
setup(TL)


numVideoFrames = TL.NumFrames;


%% FILE NAME
try
	videoFile = scicadelic.FileWrapper('FileName',TL.FileName, 'FileDirectory', TL.FileDirectory);
	defaultDataSetName = videoFile.DataSetName;
catch
	defaultDataSetName = TL.DataSetName;
end
if isempty(defaultDataSetName)
	defaultDataSetName = 'defaultdatasetname';
end
defaultExportPath = [TL.FileDirectory, 'export'];
if ~isdir(defaultExportPath)
	mkdir(defaultExportPath)
end
dateStamp = datestr(now,'(yyyymmmdd_HHMMPM)');
mp4FileName = [defaultExportPath,filesep, defaultDataSetName,'RAW ', dateStamp, '.mp4'];

%% MP4 COMPRESSION & FRAMERATE SETTINGS
% fpsMultiplier = 2;
% Tduration = TL.LastFrameTime - TL.FirstFrameTime ;
% FPSmp4 = fpsMultiplier * TL.StackInfo.numFrames/ Tduration;
FPSmp4 = 60;
FPSdescription = '2X (Approximate)';
profile = 'MPEG-4';
writerObj = VideoWriter(mp4FileName,profile);
writerObj.FrameRate = FPSmp4;
writerObj.Quality = 98;
addlistener(writerObj, 'ObjectBeingDestroyed', @(src,evnt)close(src) );
open(writerObj)

Fraw = {};
%% loop
idx = 0;
m = 0;

%%
while ~isempty(idx) && (idx(end) < numVideoFrames)
	m = m+1;
	[frameData, frameInfo, idx] = step(TL);
	frameTime = frameInfo.t;
	f=[];
	f(:,:,1,:) = uint8(256.*im2single(frameData));
	fu = uint8(repmat(f,1,1,3,1));
	
	
	% SEND RGB FRAMES TO MP4 VIDEO WRITER
	writeVideo(writerObj, fu)
	
	disp(idx)
end


close(writerObj)






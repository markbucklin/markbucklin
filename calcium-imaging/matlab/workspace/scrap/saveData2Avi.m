function saveData2Avi(F,varargin)
warning('saveData2Avi.m being called from scrap directory: Z:\Files\MATLAB\toolbox\ignition\scrap')

upperSat = .999;
lowerSat = .05;
fps = 60;
if nargin > 1
	fileName = varargin{1};
else
	[fname,fpath] = uiputfile('*.avi','Please choose a folder and file-name for avi-video');
	fileName = fullfile(fpath,fname);
end

% GET DIMENSIONS
	[numRows, numCols, dim3, dim4] = size(F);
	if dim3 < 4
		numChannels = dim3;
		numFrames = dim4;
		colorDim = 3;
		timeDim = 4;
		
	elseif dim4 < 4
		numChannels = dim4;
		numFrames = dim3;
		colorDim = 4;
		timeDim = 3;
		
	else
		error('IMRGBPLAY currently only handles 3 color channels')
		
	end

% GET LOW AND HIGH LIMITS FROM SAMPLE FRAMES
sampleIndices = round(linspace(1,numFrames,min(1000,numFrames)));
for n = 1:numel(sampleIndices)
    k = sampleIndices(n);
    sl(:,n) = stretchlim( F(:,:,:,k), [lowerSat upperSat]);
end
imLow = min(sl(1,:));
imHigh = max(sl(2,:));
% vidMax = max(cat(3,vid(:).cdata),[],3);
% vidMin = min(cat(3,vid(:).cdata),[],3);
% slMax = stretchlim(vidMax,[lowerSat upperSat]);
% slMin = stretchlim(vidMin,[lowerSat upperSat]);


vidWriteObj = VideoWriter(fileName,'Grayscale Avi');
vidWriteObj.FrameRate = fps;
vidWriteObj.open

N=numFrames;
h = waitbar(0,  sprintf('Writing frame %g of %g (%f secs/frame)',1,N,0));
tic
for k = 1:N
    f.cdata = im2single(imadjust(F(:,:,:,k),[imLow imHigh]));
    f.colormap = [];
    writeVideo(vidWriteObj,f)
	waitbar(k/N, h, ...
		sprintf('Writing frame %g of %g (%f secs/frame)',k,N,toc));
	tic
end
delete(h)

close(vidWriteObj)

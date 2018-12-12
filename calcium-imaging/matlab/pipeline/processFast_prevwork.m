function [allVidFiles, R, info, uniqueFileName] = processFast(varargin)
% This processes everything
fprintf('process fast\n')

% ------------------------------------------------------------------------------------------
% PROCESS FILENAME INPUT OR QUERY USER FOR MULTIPLE FILES
% ------------------------------------------------------------------------------------------
if nargin
  fname = varargin{1};
  switch class(fname)
	 case 'char'
		fileName = cellstr(fname);
	 case 'cell'
		fileName = cell(numel(fname),1);
		for n = 1:numel(fname)
		  fileName{n} = which(fname{n});
		end
	 case 'struct'
		fileName = {fname.name}';
		for n = 1:numel(fileName)
		  fileName{n} = which(fileName{n});
		end
  end
  fdir = pwd;
else
  [fname,fdir] = uigetfile('*.tif','MultiSelect','on');
  cd(fdir)
  switch class(fname)
	 case 'char'
		fileName{1} = [fdir,fname];
	 case 'cell'
		fileName = cell(numel(fname),1);
		for n = 1:numel(fname)
		  fileName{n} = [fdir,fname{n}];
		end
  end
end
% ------------------------------------------------------------------------------------------
% GET INFO FROM EACH TIF FILE
% ------------------------------------------------------------------------------------------
nFiles = numel(fileName);
tifFile = struct(...
  'fileName',fileName(:),...
  'tiffTags',repmat({struct.empty(0,1)},nFiles,1),...
  'nFrames',repmat({0},nFiles,1),...
  'frameSize',repmat({[1024 1024]},nFiles,1));
for n = 1:nFiles
   multiWaitbar('Aquiring Information from Each TIFF File',n/nFiles);
  tifFile(n).fileName = fileName{n};
  tifFile(n).tiffTags = imfinfo(fileName{n});
  tifFile(n).nFrames = numel(tifFile(n).tiffTags);
  tifFile(n).frameSize = [tifFile(n).tiffTags(1).Height tifFile(n).tiffTags(1).Width];
end
% multiWaitbar('Aquiring Information from Each TIFF File','Close');
nTotalFrames = sum([tifFile(:).nFrames]);
fileFrameIdx.last = cumsum([tifFile(:).nFrames]);
fileFrameIdx.first = [0 fileFrameIdx.last(1:end-1)]+1;
[tifFile.firstIdx] = deal(fileFrameIdx.first);
[tifFile.lastIdx] = deal(fileFrameIdx.last); 
% ------------------------------------------------------------------------------------------
% PROCESS FIRST FILE
% ------------------------------------------------------------------------------------------
[d8a, singleFrameRoi, procstart, info] = processFirstVidFile(tifFile(1).fileName);
% videoFileDir = [fdir, 'VideoFiles'];
% if ~isdir(videoFileDir)
%    mkdir(videoFileDir);
% end
vfile = saveVidFile(d8a,info, tifFile(1));
allVidFiles = VideoFile.empty(nFiles,0);
allVidFiles(1) = vfile;
% allVidFiles(nFiles) = vfile;
% ------------------------------------------------------------------------------------------
% PROCESS REST OF FILES (IN BACKGROUND)
% ------------------------------------------------------------------------------------------
% procFcn = @processVidFile;
for kFile = 2:numel(tifFile)
   fname = tifFile(kFile).fileName;
   fprintf(' Processing: %s\n', fname);
   [f.d8a, f.singleFrameRoi, procstart, f.info] = processVidFile(fname, procstart);
   vfile = saveVidFile(f.d8a, f.info, tifFile(kFile));
   allVidFiles(kFile,1) = vfile;
   %    d8a = cat(3,d8a, f.d8a);
   singleFrameRoi = cat(1,singleFrameRoi, f.singleFrameRoi);
   info = cat(1,info, f.info);
end
% ------------------------------------------------------------------------------------------
% ONCE VIDEO HAS BEEN PROCESSED
% ------------------------------------------------------------------------------------------
uniqueFileName = procstart.commonFileName;
save(fullfile(fdir, 'processedvideofiles.mat'), 'allVidFiles');
singleFrameRoi = fixFrameNumbers(singleFrameRoi);
saveRoiExtract(singleFrameRoi,fdir)

R = reduceRegions(singleFrameRoi);
for k=1:numel(R)
   fds(k,1) = sum(diff(R(k).Frames) == 1) / sum(diff(R(k).Frames) > 10); 
end
save('allROI','R')
fdsmin = 1;
while sum(fds >= fdsmin) > 1000
   fdsmin = fdsmin + .1;
end
R = R(fds >= fdsmin);
save('significantROI','R')
end










% ################################################################
% SUBFUNCTIONS
% ################################################################

function [d8a, singleFrameRoi, procstart, info] = processFirstVidFile(fname)
% LOAD FILE
[data, info, tifFile] = loadTifInline(fname);

% GET COMMON FILE-/FOLDER-NAME
[fp,~] = fileparts(tifFile.fileName);
[~,fp] = fileparts(fp);
procstart.commonFileName = fp;
nFiles = numel(tifFile);
nTotalFrames = info(end).frame;
fprintf('Loading %s from %i files (%i frames)\n', procstart.commonFileName, nFiles, nTotalFrames);

% ------------------------------------------------------------------------------------------
% FILTER & NORMALIZE VIDEO, AND SAVE AS UINT8
% ------------------------------------------------------------------------------------------
% PRE-FILTER TO CORRECT FOR UNEVEN ILLUMINATION (HOMOMORPHIC FILTER)
data = homomorphicFilter(data);

% CORRECT FOR MOTION (IMAGE STABILIZATION)
[data, procstart.xc, procstart.prealign] = correctMotion(data);

% FILTER AGAIN
data = homomorphicFilter(data);

% NORMALIZE DATA -> dF/F
[data, procstart.preNormalize] = normalizeData(data);
%filteragain?

% SUBTRACT BASELINE
data = subtractBaseline(data);

% LOW-PASS FILTER TO REMOVE 6-8HZ MOTION ARTIFACTS
[data, procstart.filtobj] = tempAndSpatialFilter(data);


d8a = im2uint8(data);
singleFrameRoi = detectSingleFrameRois(d8a,info);
end

function [d8a, singleFrameRoi, procstart, info] = processVidFile(fname, procstart)
% LOAD FILE
[data, info, tifFile] = loadTifInline(fname);
% GET COMMON FILE-/FOLDER-NAME
nFiles = numel(tifFile);
nTotalFrames = info(end).frame;
fprintf('Loading %s from %i files (%i frames)\n', procstart.commonFileName, nFiles, nTotalFrames);
% ------------------------------------------------------------------------------------------
% FILTER & NORMALIZE VIDEO, AND SAVE AS UINT8
% ------------------------------------------------------------------------------------------
% PRE-FILTER TO CORRECT FOR UNEVEN ILLUMINATION (HOMOMORPHIC FILTER)
data = homomorphicFilter(data);
% CORRECT FOR MOTION (IMAGE STABILIZATION)
[data, procstart.xc, procstart.prealign] = correctMotion(data, procstart.prealign);
% FILTER AGAIN
data = homomorphicFilter(data);
% NORMALIZE DATA -> dF/F
[data, procstart.preNormalize] = normalizeData(data, procstart.preNormalize);
% SUBTRACT BASELINE
data = subtractBaseline(data);
% LOW-PASS FILTER TO REMOVE 6-8HZ MOTION ARTIFACTS
[data, procstart.filtobj] = tempAndSpatialFilter(data);
% OUTPUTS
d8a = im2uint8(data);
singleFrameRoi = detectSingleFrameRois(d8a,info);
end

function vfile = saveVidFile(data,info,tifFile)
[expDir, expName] = fileparts(tifFile.fileName);
vfile = VideoFile('rootPath',expDir,'experimentName',expName,'bitDepth',8);
vfinfo.FrameNumber = cat(1,info.frame);
vfinfo.time = cat(1,info.t);
vfile.addFrame2File(data,vfinfo);
vidFileDir = [expDir, '\', 'VidFiles'];
if ~isdir(vidFileDir)
   mkdir(vidFileDir);
end
save(fullfile(vidFileDir,expName), 'vfile');
end

function [data, varargout] = loadTifInline(varargin)

% PROCESS ARGUMENTS (fileName) OR ASK TO PICK FILE
if nargin
  fname = varargin{1};
  switch class(fname)
	 case 'char'
		fileName = cellstr(fname);
	 case 'cell'
		fileName = cell(numel(fname),1);
		for n = 1:numel(fname)
		  fileName{n} = which(fname{n});
		end
  end
else
  [fname,fdir] = uigetfile('*.tif','MultiSelect','on');
  switch class(fname)
	 case 'char'
		fileName{1} = [fdir,fname];
	 case 'cell'
		fileName = cell(numel(fname),1);
		for n = 1:numel(fname)
		  fileName{n} = [fdir,fname{n}];
		end
  end
end

% GET INFO FROM EACH TIF FILE
nFiles = numel(fileName);
tifFile = struct(...
  'fileName',fileName(:),...
  'tiffTags',repmat({struct.empty(0,1)},nFiles,1),...
  'nFrames',repmat({0},nFiles,1),...
  'frameSize',repmat({[1024 1024]},nFiles,1));
for n = 1:numel(fileName)
  tifFile(n).fileName = fileName{n};
  tifFile(n).tiffTags = imfinfo(fileName{n});
  tifFile(n).nFrames = numel(tifFile(n).tiffTags);
  tifFile(n).frameSize = [tifFile(n).tiffTags(1).Height tifFile(n).tiffTags(1).Width];
end
nTotalFrames = sum([tifFile(:).nFrames]);
fileFrameIdx.last = cumsum([tifFile(:).nFrames]);
fileFrameIdx.first = [0 fileFrameIdx.last(1:end-1)]+1;
[tifFile.firstIdx] = deal(fileFrameIdx.first);
[tifFile.lastIdx] = deal(fileFrameIdx.last);

% PREINSTANTIATE STRUCTURE ARRAY FOR IMAGE DATA
blankFrame = zeros(tifFile(1).frameSize, 'uint16');
data = repmat(blankFrame, [1 1 nTotalFrames]);

info = struct(...
  'frame',repmat({0},nTotalFrames,1),...
  'subframe',repmat({0},nTotalFrames,1),...
  'tiffTag',repmat({tifFile(1).tiffTags(1)},nTotalFrames,1),...
  't',NaN,...
  'timestamp',struct('hours',NaN,'minutes',NaN,'seconds',NaN));

% FILL INFO STRUCTURE
for n=1:numel(tifFile)
  firstFrame = fileFrameIdx.first(n);
  lastFrame = fileFrameIdx.last(n);
  tifInfo = tifFile(n).tiffTags;
  subk = 1;
  for k = firstFrame:lastFrame
	 info(k).frame = k;
	 info(k).subframe = subk;
	 info(k).tiffTag = tifInfo(subk);
	 info(k).timestamp = getHcTimeStamp(info(k).tiffTag);
	 info(k).t = info(k).timestamp.seconds;
	 subk = subk + 1;
  end
end

%SHOW WAITBAR
[fp,~] = fileparts(tifFile(1).fileName);
[~,fp] = fileparts(fp);
fprintf('Loading %s from %i files (%i frames)\n', fp, nFiles, nTotalFrames);
wbString = sprintf('Loading %s from %i files (%i frames)', fp, nFiles, nTotalFrames);
multiWaitbar(wbString,0)
tProc = hat;

% INLINE TIF LOAD
for n = 1:numel(tifFile)
  warning('off','MATLAB:imagesci:tiffmexutils:libtiffWarning')
  warning off MATLAB:tifflib:TIFFReadDirectory:libraryWarning
  tiffFileName = tifFile(n).fileName;
  InfoImage = tifFile(n).tiffTags;
  
  %   tifObj = Tiff(tiffFileName,'r');
  firstFrame = fileFrameIdx.first(n);
  lastFrame = fileFrameIdx.last(n);
  nSubFrames = tifFile(n).nFrames;
  fprintf('Loading frames %g to %g from %s\n',firstFrame,lastFrame,tifFile(n).fileName);
    
  nImage = InfoImage(1).Height;
  FileID = tifflib('open',tiffFileName,'r');
  rps = tifflib('getField',FileID,Tiff.TagID.RowsPerStrip);
  
  for ksf = 1:nSubFrames
	 multiWaitbar(wbString, 'Increment', 1/nTotalFrames);
	 tifflib('setDirectory',FileID,ksf - 1);
	 kFrame = fileFrameIdx.first(n) + ksf - 1;
	 fillFrame = zeros(tifFile(1).frameSize, 'uint16');
	 % Go through each strip of data.
	 rps = min(rps,nImage);
	 for r = 1:rps:nImage
		  row_inds = r:min(nImage,r+rps-1);
		  stripNum = tifflib('computeStrip', FileID, r) - 1;
		  fillFrame(row_inds,:) =  tifflib('readEncodedStrip',FileID,stripNum);
		  % 		  data(row_inds,:,kFrame) = tifflib('readEncodedStrip',FileID,stripNum);
	 end
	 data(:,:,kFrame) = fillFrame;
  end
  tifflib('close',FileID);
end

tProc = hat - tProc;
fprintf([mfilename, ':\t Loaded %i frames in %3.4g seconds \t(%3.4g ms/frame\n\n'],...
   1000*tProc/nTotalFrames);
% multiWaitbar(wbString, 'Close')
if nargout > 1
  varargout{1} = info;
  if nargout > 2
	 varargout{2} = tifFile;
  end
end
end

function data = homomorphicFilter(data,varargin)
% Implemented by Mark Bucklin 6/12/2014
%
% FROM WIKIPEDIA ENTRY ON HOMOMORPHIC FILTERING
% Homomorphic filtering is a generalized technique for signal and image
% processing, involving a nonlinear mapping to a different domain in which
% linear filter techniques are applied, followed by mapping back to the
% original domain. This concept was developed in the 1960s by Thomas
% Stockham, Alan V. Oppenheim, and Ronald W. Schafer at MIT.
%
% Homomorphic filter is sometimes used for image enhancement. It
% simultaneously normalizes the brightness across an image and increases
% contrast. Here homomorphic filtering is used to remove multiplicative
% noise. Illumination and reflectance are not separable, but their
% approximate locations in the frequency domain may be located. Since
% illumination and reflectance combine multiplicatively, the components are
% made additive by taking the logarithm of the image intensity, so that
% these multiplicative components of the image can be separated linearly in
% the frequency domain. Illumination variations can be thought of as a
% multiplicative noise, and can be reduced by filtering in the log domain.
%
% To make the illumination of an image more even, the high-frequency
% components are increased and low-frequency components are decreased,
% because the high-frequency components are assumed to represent mostly the
% reflectance in the scene (the amount of light reflected off the object in
% the scene), whereas the low-frequency components are assumed to represent
% mostly the illumination in the scene. That is, high-pass filtering is
% used to suppress low frequencies and amplify high frequencies, in the
% log-intensity domain.[1]
%
% More info HERE: http://www.cs.sfu.ca/~stella/papers/blairthesis/main/node35.html
%% DEFINE PARAMETERS and PROCESS INPUT

gpu = gpuDevice(1);

% CONSTRUCT HIGH-PASS (or Low-Pass) FILTER
if nargin>1
   sigma = varargin{1};
else
   sigma = 50;
end
filtSize = 2 * sigma + 1;
hLP = gpuArray(fspecial('gaussian',filtSize,sigma));

% GET RANGE FOR CONVERSION TO FLOATING POINT INTENSITY IMAGE
dmax = getNearMax(data);
dmin = getNearMin(data);
inputScale = single(dmax - dmin);
inputOffset = single(dmin);
outputRange = [0 65535];
outputScale = outputRange(2) - outputRange(1);
outputOffset = outputRange(1);

% PROCESS FRAMES IN BATCHES TO AVOID PAGEFILE SLOWDOWN
sz = size(data);
N = sz(3);
nPixPerFrame = sz(1) * sz(2);
nBytesPerFrame = nPixPerFrame * 2;


multiWaitbar('Applying Homomorphic Filter',0);
for k=1:N
   %    if nBytesPerFrame > gpu.AvailableMemory
   % 	  wait(gpu);
   %    end
   multiWaitbar('Applying Homomorphic Filter', 'Increment', 1/N);
   data(:,:,k) = homFiltSingleFrame(data(:,:,k));
end
% multiWaitbar('Applying Homomorphic Filter','Close');

   function im = homFiltSingleFrame( im)
	  persistent ioLast
	  % TRANSFER TO GPU AND CONVERT TO DOUBLE-PRECISION INTENSITY IMAGE
	  imGray =  (single(gpuArray(im)) - inputOffset)./inputScale   + 1;					% {1..2}
	  % USE MEAN TO DETERMINE A SCALAR BASELINE ILLUMINATION INTENSITY IN LOG DOMAIN
	  io = log( mean(imGray(imGray<median(imGray(:))))); % mean of lower 50% of pixels		% {0..0.69}
	  if isnan(io)
		 if ~isempty(ioLast) 
			io = ioLast; 
		 else
			io = .1;
		 end
	  end
	  % LOWPASS-FILTERED IMAGE (IN LOG-DOMAIN) REPRESENTS UNEVEN ILLUMINATION
	  imGray = log(imGray);																				% log(imGray) -> {0..0.69}
	  imLp = imfilter( imGray, hLP, 'replicate');														%  imLp -> ?
	  % SUBTRACT LOW-FREQUENCY "ILLUMINATION" COMPONENT
	  imGray = exp( imGray - imLp + io) - 1;			% {0..2.72?} -> {-1..1.72?}
	  % RESCALE FOR CONVERSION BACK TO ORIGINAL DATATYPE
	  imGray = imGray .* outputScale  + outputOffset;	 
	  % CLEAN UP LOW-END (SATURATE TO ZERO OR 100)
	  % 	  im(im<outputRange(1)) = outputRange(1);
	  % CAST TO ORIGINAL DATATYPE (UINT16) AND RETURN
	  im = gather(uint16(imGray));
	  ioLast = io;
   end
end

function dataSample = getDataSample(data,varargin)
% Returns a randomized sample of data-frames (previously getVidSample)
N = size(data,3);
if nargin > 1
	nSampleFrames = varargin{1};
else
	nSampleFrames = min(N, 100);
end
jitter = floor(N/nSampleFrames);
sampleFrameNumbers = round(linspace(1, N-jitter, nSampleFrames)')...
 + round( jitter*rand(nSampleFrames,1));
dataSample = data(:,:,sampleFrameNumbers);
end

function [data, xc, prealign] = correctMotion(data, prealign)
sz = size(data);
nFrames = sz(3);
if nargin < 2
   %    prealign.hMean = vision.Mean(...
   % 	  'RunningMean',true,...
   % 	  'Dimension',3);
   prealign.cropBox = selectWindowForMotionCorrection(data,sz(1:2)./2);
   prealign.n = 0;
end
ySubs = round(prealign.cropBox(2): (prealign.cropBox(2)+prealign.cropBox(4)-1)');
xSubs = round(prealign.cropBox(1): (prealign.cropBox(1)+prealign.cropBox(3)-1)');
croppedVid = gpuArray(data(ySubs,xSubs,:));
% croppedVid = im2single(data(ySubs,xSubs,:));
cropSize = size(croppedVid);
maxOffset = floor(min(cropSize(1:2))/10);
ysub = maxOffset+1 : cropSize(1)-maxOffset;
xsub = maxOffset+1 : cropSize(2)-maxOffset;
yPadSub = maxOffset+1 : sz(1)+maxOffset;
xPadSub = maxOffset+1 : sz(2)+maxOffset;
if ~isfield(prealign, 'template')
   vidMean = im2single(croppedVid(:,:,1));
   templateFrame = vidMean(ysub,xsub);
else
   templateFrame = gpuArray(prealign.template);
end
offsetShift = min(size(templateFrame)) + maxOffset;
validMaxMask = [];
N = nFrames;
xc.cmax = zeros(N,1);
xc.xoffset = zeros(N,1);
xc.yoffset = zeros(N,1);
multiWaitbar('Generating normalized cross-correlation offset', 0);
for k = 1:N   
   multiWaitbar('Generating normalized cross-correlation offset', k/N);
   movingFrame = im2single(croppedVid(:,:,k));
   c = normxcorr2(templateFrame, movingFrame);
   % Restrict available peaks in xcorr matrix
   if isempty(validMaxMask)
	  validMaxMask = false(size(c));
	  validMaxMask(offsetShift-maxOffset:offsetShift+maxOffset, offsetShift-maxOffset:offsetShift+maxOffset) = true;
   end
   c(~validMaxMask) = false;
   c(c<0) = false;
   % find peak in cross correlation
   [cmax, imax] = max(abs(c(:)));
   [ypeak, xpeak] = ind2sub(size(c),imax(1));
   % account for offset from padding?
   xoffset = xpeak - offsetShift;
   yoffset = ypeak - offsetShift;
   % APPLY OFFSET TO TEMPLATE AND ADD TO VIDMEAN
   adjustedFrame = movingFrame(ysub+yoffset , xsub+xoffset);
   % 		imagesc(circshift(movingFrame(ysub,xsub),-[yoffset xoffset]) - templateFrame), colorbar
   nt = prealign.n / (prealign.n + 1);
   na = 1/(prealign.n + 1);
   templateFrame = templateFrame*nt + adjustedFrame*na;
   prealign.n = prealign.n + 1;
   xc.cmax(k) = gather(cmax);
   dx = gather(xoffset);
   dy = gather(yoffset);
   xc.xoffset(k) = dx;
   xc.yoffset(k) = dy;
   % APPLY OFFSET TO VIDEO STRUCT
   padFrame = padarray(data(:,:,k), [maxOffset maxOffset], 'replicate', 'both');
   data(:,:,k) = padFrame(yPadSub+dy, xPadSub+dx);
end
prealign.template = gather(templateFrame);
% multiWaitbar('Generating normalized cross-correlation offset', 'Close');
end

function winRectangle = selectWindowForMotionCorrection(data, winsize)

if numel(winsize) <2
  winsize = [winsize winsize];
end

sz = size(data);
win.edgeOffset = round(sz(1:2)./4);
win.rowSubs = win.edgeOffset(1):sz(1)-win.edgeOffset(1);
win.colSubs =  win.edgeOffset(2):sz(2)-win.edgeOffset(2);

% vidSample = getDataSample(data);
stat.Range = range(data, 3);
stat.Min = min(data, [], 3);

imRobust = double(imfilter(rangefilt(stat.Min),fspecial('average',50))) ./ double(imfilter(stat.Range, fspecial('average',50)));
imRobust = imRobust(win.rowSubs, win.colSubs);
[~, maxInd] = max(imRobust(:));
[win.rowMax, win.colMax] = ind2sub([length(win.rowSubs) length(win.colSubs)], maxInd);
win.rowMax = win.rowMax + win.edgeOffset(1);
win.colMax = win.colMax + win.edgeOffset(2);
win.rows = win.rowMax-winsize(1)/2+1 : win.rowMax+winsize(1)/2;
win.cols = win.colMax-winsize(2)/2+1 : win.colMax+winsize(2)/2;

winRectangle = [win.cols(1) , win.rows(1) , win.cols(end)-win.cols(1) , win.rows(end)-win.rows(1)];
end

function [data, preNormalize] = normalizeData(data, preNormalize)

if nargin < 2
   % BASELINE FLUORESCENCE IS AVERAGE OF 1st-30th PERCENTILE WRT TIME
   preNormalize.pctiles = [1:98, 98.5, 99, 99.1:.1:99.9];
   pcLow = find(preNormalize.pctiles == 1);
   pcHigh = find(preNormalize.pctiles == 30);
   preNormalize.impc = prctile(double(data),preNormalize.pctiles,3);
   preNormalize.baseline = mean(preNormalize.impc(:,:, pcLow:pcHigh), 3);
   preNormalize.nAv = 0;
   preNormalize.offset = 100;
   %   dmr = range(data,3);
   %   preNormalize.offset = mean(dmr(:),'double');
end

N = size(data,3);
F0 = preNormalize.baseline;
normData = bsxfun(@rdivide, bsxfun(@minus, double(data), F0), F0);

% CONVERT BACK TO UINT16
data = uint16(normData .* 65535);

end

function data = subtractBaseline(data)
% SUBTRACT RESULTING BASELINE THAT STILL EXISTS IN NEUROPIL
activityImage = imfilter(range(data,3), fspecial('average',201), 'replicate');
npMask = double(activityImage) < mean2(activityImage);
npPixNum = sum(npMask(:));
npBaseline = sum(sum(bsxfun(@times, double(data), npMask), 1), 2) ./ npPixNum; %average of pixels in mask
% npBaseline = npBaseline(:);
data = uint16(bsxfun(@minus, data, uint16(npBaseline)));
end

function [data, varargout] = tempAndSpatialFilter(data,fps,varargin)

if nargin < 2
   fps = 20;
   fnyq = fps/2;
end
if nargin < 3
   % FIR FILTER
   n = 50;
   fstop = 5; %Hz
   wstop = fstop/fnyq;
   % DESIGNED FILTER
   d = designfilt('lowpassfir','SampleRate',fps, 'PassbandFrequency',fstop-.5, ...
	  'StopbandFrequency',fstop+.5,'PassbandRipple',0.5, ...
	  'StopbandAttenuation',65,'DesignMethod','kaiserwin');%could also use butter,cheby1/2,equiripple
else
   d = varargin{1};
end

data = spatialFilter(data);
data = temporalFilter(data,d);


   function dmat = temporalFilter(dmat,d)
	  [phi,~] = phasedelay(d,1:5,fps);
	  phaseDelay = mean(phi(:));
	  h = d.Coefficients;
	  h = double(h);
	  filtPad = ceil(phaseDelay*4);
	  % APPLY TEMPORAL FILTER
	  sz = size(dmat);
	  npix = sz(1)*sz(2);
	  nframes = sz(3);
	  % sdata = fftfilt( gpuArray(h), double( reshape( gpuArray(data), [npix,nframes])' ));
	  sdata = filter( h, 1, double( cat(3, flip(dmat(:,:,1:filtPad),3),dmat)), [], 3);
	  dmat = uint16(sdata(:,:,filtPad+1:end));
   end

   function dmat = spatialFilter(dmat)
	  N = size(dmat,3);
	  medFiltSize = [3 3];
	  for k=1:N
		 dmat(:,:,k) = gather(medfilt2(gpuArray(dmat(:,:,k)), medFiltSize));
	  end
   end

if nargout > 1
   varargout{1} = d;
end
end

function roi = detectSingleFrameRois(data,info)
% INPUT:
%	Expects vid.cdata with cdata datatype = 'uint8'
% OUTPUT:
%	Array of objects of the 'RegionOfInterest' class, resembling a RegionProps structure
%	(Former Output)
%	Returns structure array, same size as vid, with fields
%			bwvid =
%				RegionProps: [12x1 struct]
%				bwMask: [1024x1024 logical]

% GET SAMPLE VIDEO STATISTICS AND DEFINE MIN/MAX ROI AREA
sz = size(data);
N = sz(3);
frameSize = sz(1:2);
dsamp = getDataSample(data);
stat.Min = min(dsamp,[],3);
stat.Std = std(double(dsamp),1,3);
minRoiPixArea = 50; %previously 50
maxRoiPixArea = 250; %previously 350, then 650
maxRoiEccentricity = .92;
maxPerimOverSqArea = 6; %  circle = 3.5449, square = 4 % Previousvalues: [6.5  ]
minPerimOverSqArea = 3.5;
% INITIALIZE DYNAMIC SIGNAL THRESHOLD ARRAY: ~1 STD. DEVIATION OVER MINIMUM (OVER TIME)
stdOverMin = 1.5; % formerly 1.2
signalThreshold = gpuArray( stat.Min + uint8( stat.Std.*stdOverMin ));
% RUN A FEW FRAMES THROUGH HOTSPOT FINDING FUNCTION TO IMPROVE INITIAL SIGNAL THRESHOLD
for k = fliplr(round(linspace(1,N,min(20,N))))
  [~, signalThreshold] = getAdaptiveHotspots(data(:,:,k), signalThreshold);
end
% GET HOTSPOT-BASED ROIS (WHENEVER SIGNAL INTENSITY EXCEEDS PIXEL-SPECIFIC THRESHOLD)
bwmask = false([frameSize N]);
for k = 1:N
  [bwmask(:,:,k), signalThreshold] = getAdaptiveHotspots(data(:,:,k), signalThreshold);
end
if nargin<2
   info = [];
   frameNum = 1:N;
else
   frameNum = cat(1,info.frame);
end
frameROI = cell(N,1);
parfor kp = 1:N
  % EVALUATE CONNECTED COMPONENTS FROM BINARY 'BLOBBED' MATRIX: ENFORCE MORPHOLOGY RESTRICTIONS
  bwRP =  regionprops(bwmask(:,:,kp),...
	 'Centroid', 'BoundingBox','Area',...
	 'Eccentricity', 'PixelIdxList','Perimeter');
  bwRP = bwRP([bwRP.Area] >= minRoiPixArea);	%	Enforce MINIMUM SIZE
  bwRP = bwRP([bwRP.Area] <= maxRoiPixArea);	%	Enforce MAXIMUM SIZE
  bwRP = bwRP([bwRP.Eccentricity] <= maxRoiEccentricity); %  Enforce PLUMP SHAPE
  bwRP = bwRP([bwRP.Perimeter]./sqrt([bwRP.Area]) < maxPerimOverSqArea); %  Enforce LOOSELY CIRCULAR/SQUARE SHAPE
  bwRP = bwRP([bwRP.Perimeter]./sqrt([bwRP.Area]) > minPerimOverSqArea); %  Enforce NON-HOLINESS (SELF-FULFILLMENT?)
  if isempty(bwRP)
	 continue
  end
  % FILL 'REGIONOFINTEREST' CLASS OBJECTS (several per frame)
  frameROI{kp,1} = RegionOfInterest(bwRP);
  set(frameROI{kp,1},...
	 'Frames',frameNum(kp),...
	 'FrameSize',frameSize);
end
roi = cat(1,frameROI{:});
% ------------ SUBFUNCTIONS -------------------
% FUNCTION TO MAKE BINARY MASK WITH ADAPTIVE THRESHOLD
  function [bw, sigThresh]  = getAdaptiveHotspots(diffImage, sigThresh)
	 coverageMaxRatio = .025; %  .01 = 10K pixels (15-30 cells?)
	 coverageMinPixels = 250; % previous values: 500
	 thresholdStep = 1;
	 % PREVENT RACE CONDITION OR NON-SETTLING THRESHOLD
	 persistent depth
	 if isempty(depth)
		depth = 0;
	 else
		depth = depth + 1;
	 end
	 if depth > 256
		warning('256 iterations exceeded')
		depth = 0;
		return
	 end
	 % USE THRESHOLD MATRIX TO MAKE BINARY IMAGE, THEN APPLY MORPHOLOGICAL OPERATIONS
	 diffImage = gpuArray(diffImage);
	 bw = diffImage > sigThresh;
	 % changed from: bw = imclose(imopen( bw, S.disk6), S.disk4);
	 bw = gather(bwmorph(bwmorph(bwmorph( bw, 'open'), 'shrink'), 'majority'));%4
	 % can also try: 'hbreak'  'shrink' 'fill'  'open' gpuArray
	 % CHECK FOR OVER/UNDER-THRESHOLDING
	 numPix = numel(bw);
	 sigThreshPix = sum(bw(:));
	 binaryCoverage = sigThreshPix/numPix;
	 if binaryCoverage > coverageMaxRatio
		sigThresh = sigThresh + thresholdStep;
		[bw, sigThresh]  = getAdaptiveHotspots(diffImage, sigThresh);
	 elseif sigThreshPix < coverageMinPixels
		sigThresh = sigThresh - thresholdStep;
		[bw, sigThresh]  = getAdaptiveHotspots(diffImage, sigThresh);
	 else
		depth = 0;
	 end
  end

end

function singleFrameRoi = fixFrameNumbers(singleFrameRoi)
fnum = cat(1,singleFrameRoi.Frames);
fset = cumsum(diff([1;fnum])<0);
fnum = fnum + fset * max(fnum(:));
for k=1:numel(singleFrameRoi)
   singleFrameRoi(k).Frames = fnum(k);
end
end









% GET FILES FROM DIRECTORY
% dlist = dir
%  dlist = dlist(~cellfun(@isdir,{dlist.name}))






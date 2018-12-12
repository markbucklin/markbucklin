function varargout = processFast4Will(varargin)
% function [allVidFiles, R, info, uniqueFileName] = processFast(varargin)
% This processes everything
fprintf('process fast\n')
try
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
  [fdir, ~] = fileparts(which(fileName{1}));
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
vidStats(1) = getVidStats(d8a);
vidProcSum(1) = procstart;
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
vidStats(numel(tifFile),1) = vidStats(1);
vidProcSum(numel(tifFile),1) = vidProcSum(1);
for kFile = 2:numel(tifFile)
  fname = tifFile(kFile).fileName;
  fprintf(' Processing: %s\n', fname);
  [f.d8a, f.singleFrameRoi, procstart, f.info] = processVidFile(fname, procstart);
  vidStats(kFile) = getVidStats(f.d8a);
  vidProcSum(kFile) = procstart;
  vfile = saveVidFile(f.d8a, f.info, tifFile(kFile));
  allVidFiles(kFile,1) = vfile;
  %    d8a = cat(3,d8a, f.d8a);
  singleFrameRoi = cat(1,singleFrameRoi, f.singleFrameRoi);
  info = cat(1,info, f.info);
end
catch me
   keyboard
end
% ------------------------------------------------------------------------------------------
% ONCE VIDEO HAS BEEN PROCESSED - CREATE FILENAMES AND SAVE VIDEO
% ------------------------------------------------------------------------------------------
try
  uniqueFileName = procstart.commonFileName;
  saveTime = now;
  processedVidFileName =  ...
	 ['Processed_VideoFiles_',...
	 uniqueFileName,'_',...
	 datestr(saveTime,'yyyy_mm_dd_HHMM'),...
	 '.mat'];
  processedStatsFileName =  ...
	 ['Processed_VideoStatistics_',...
	 uniqueFileName,'_',...
	 datestr(saveTime,'yyyy_mm_dd_HHMM'),...
	 '.mat'];
  processingSummaryFileName =  ...
	 ['Processing_Summary_',...
	 uniqueFileName,'_',...
	 datestr(saveTime,'yyyy_mm_dd_HHMM'),...
	 '.mat'];
  roiFileName = ...
	 ['Processed_ROIs_',...
	 uniqueFileName,'_',...
	 datestr(saveTime,'yyyy_mm_dd_HHMM'),...
	 '.mat'];
  save(fullfile(fdir, processedVidFileName), 'allVidFiles');
  save(fullfile(fdir, processedStatsFileName), 'vidStats', '-v6');
  save(fullfile(fdir, processingSummaryFileName), 'vidProcSum', '-v6');
  % ------------------------------------------------------------------------------------------
  % MERGE/REDUCE REGIONS OF INTEREST
  % ------------------------------------------------------------------------------------------
  singleFrameRoi = fixFrameNumbers(singleFrameRoi);
  saveRoiExtract(singleFrameRoi,fdir)
  try
	 R = reduceRegions(singleFrameRoi);
  catch me
	 R = singleFrameRoi(1:500);
	 R = R.removeEmpty();
	 save('pseudo_ROIs', 'R')
	 keyboard
  end
  try
	 R = reduceSuperRegions(R);
  catch me
	 save('pseudo_Reduced_ROIs', 'R')
	 keyboard
  end
  % ------------------------------------------------------------------------------------------
  % SAVE TOP 1000 ROIs ACCORDING TO 'FrameDifferenceSum' INDEX
  % ------------------------------------------------------------------------------------------
%   fds = zeros(numel(R),1);
%   for k=1:numel(R)
% 	 fds(k,1) = sum(diff(R(k).Frames) == 1) / sum(diff(R(k).Frames) > 2);
%   end
  save('allROI','R')
%   fdsmin = 0;
%   while sum(fds >= fdsmin) > 1000
% 	 fdsmin = fdsmin + .1;
%   end
%   R = R(fds >= fdsmin);
delete(gcp)
  % ------------------------------------------------------------------------------------------
  % RELOAD DATA AND MAKE ROI TRACES (NORMALIZED TO WINDOWED STD)
  % ------------------------------------------------------------------------------------------
  [data, vidinfo] = getData(allVidFiles);
  data = squeeze(data);
  Xraw = makeTraceFromVid(R,data);
  %TODO: FIX THIS DETRENDING NORMALIZING THING
  %   fs=20;
  %   winsize = 1*fs;
  %   numwin = floor(size(X,1)/winsize)-1;
  %   xRange = zeros(numwin,size(X,2));
  %   for k=1:numwin
  % 	 windex = (winsize*(k-1)+1):(winsize*(k-1)+20);
  % 	 xRange(k,:) = range(detrend(X(windex,:)), 1);
  %   end
  %   Xraw = X;%new
  %   X = bsxfun(@rdivide, X, mean(xRange,1)); 
  % FILTER AND NORMALIZE TRACES AFTER COPYING TRACE TO RAWTRACE
  for k=1:numel(R)
	 R(k).RawTrace = Xraw(:,k);%new
	 % 	 R(k).Trace = X(:,k);
  end
  R.normalizeTrace2WindowedRange
  R.makeBoundaryTrace
  R.filterTrace
  % SAVE AND RETURN OUTPUTS (OR ASSIGN IN BASE)
  save(fullfile(fdir,roiFileName), 'R');
  if nargout > 0
	 varargout{1} = allVidFiles;
	 if nargout > 1
		varargout{2} = R;
		if nargout > 2
		   varargout{3} = info;
		   if nargout > 3
			  varargout{4} = uniqueFileName;
		   end
		end
	 else
		assignin('base','allVidFiles',allVidFiles)
	 end
  else
	 assignin('base','R',R)
  end
catch me
  keyboard
end

end









% ################################################################
% SUBFUNCTIONS
% ################################################################
function [d8a, singleFrameRoi, procstart, info] = processFirstVidFile(fname)
try
% LOAD FILE
[data, info, tifFile] = loadTif(fname);
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
[data, procstart.hompre] = homomorphicFilter(data);
% CORRECT FOR MOTION (IMAGE STABILIZATION)
[data, procstart.xc, procstart.prealign] = correctMotion(data);
% FILTER AGAIN
% data = homomorphicFilter(data);
% data = spatialFilter(data);
% NORMALIZE DATA -> dF/F
[data, procstart.normpre] = normalizeData(data);
% data = subtractRail2RailNoise(data);
% SUBTRACT BASELINE
% [data, procstart.lastFrame] = subtractBaseline(data);
% LOW-PASS FILTER TO REMOVE 6-8HZ MOTION ARTIFACTS
% [data, procstart.filtobj] = tempAndSpatialFilter(data);
d8a = uint8(data .* (255/65535));
singleFrameRoi = detectSingleFrameRois(d8a,info);
catch me
   keyboard
end
end
function [d8a, singleFrameRoi, procstart, info] = processVidFile(fname, procstart)
% LOAD FILE
[data, info, tifFile] = loadTif(fname);
% GET COMMON FILE-/FOLDER-NAME
nFiles = numel(tifFile);
nTotalFrames = info(end).frame;
fprintf('Loading %s from %i files (%i frames)\n', procstart.commonFileName, nFiles, nTotalFrames);
% ------------------------------------------------------------------------------------------
% FILTER & NORMALIZE VIDEO, AND SAVE AS UINT8
% ------------------------------------------------------------------------------------------
% PRE-FILTER TO CORRECT FOR UNEVEN ILLUMINATION (HOMOMORPHIC FILTER)
[data, procstart.hompre] = homomorphicFilter(data, procstart.hompre);
% CORRECT FOR MOTION (IMAGE STABILIZATION)
[data, procstart.xc, procstart.prealign] = correctMotion(data, procstart.prealign);
% FILTER AGAIN
% data = homomorphicFilter(data);
% data = spatialFilter(data);
% NORMALIZE DATA -> dF/F
[data, procstart.normpre] = normalizeData(data, procstart.normpre);
% data = subtractRail2RailNoise(data);
% SUBTRACT BASELINE
% [data, procstart.lastFrame] = subtractBaseline(data, procstart.lastFrame);
% LOW-PASS FILTER TO REMOVE 6-8HZ MOTION ARTIFACTS
% [data, procstart.filtobj] = tempAndSpatialFilter(data);
% OUTPUTS
d8a = uint8(data .* (255/(65535)));
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
function [data, varargout] = loadTif(varargin)

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
  't',NaN);%,...
%   'timestamp',struct('hours',NaN,'minutes',NaN,'seconds',NaN));

% FILL INFO STRUCTURE
tSec = 0;
for n=1:numel(tifFile)
  firstFrame = fileFrameIdx.first(n);
  lastFrame = fileFrameIdx.last(n);
  tifInfo = tifFile(n).tiffTags;
  subk = 1;
  for k = firstFrame:lastFrame
	 info(k).frame = k;
	 info(k).subframe = subk;
	 info(k).tiffTag = tifInfo(subk);
% 	 info(k).timestamp = getHcTimeStamp(info(k).tiffTag);
	 info(k).t = tSec;%info(k).timestamp.seconds;
	 subk = subk + 1;
	 tSec = tSec + .05;% ADDED FOR WILL HERE (not using HC Timestamp)
  end
end

%SHOW WAITBAR
[fp,~] = fileparts(tifFile(1).fileName);
[~,fp] = fileparts(fp);
% fprintf('Loading %s from %i files (%i frames)\n', fp, nFiles, nTotalFrames);
wbString = sprintf('Loading %s from %i files (%i frames)', fp, nFiles, nTotalFrames);
multiWaitbar(wbString,0)
% tProc = hat;

% TIF LOAD
for n = 1:numel(tifFile)
  warning('off','MATLAB:imagesci:tiffmexutils:libtiffWarning')
  warning off MATLAB:tifflib:TIFFReadDirectory:libraryWarning
  tiffFileName = tifFile(n).fileName;
  %    InfoImage = tifFile(n).tiffTags;
  
  tifObj = Tiff(tiffFileName,'r');
  %    firstFrame = fileFrameIdx.first(n);
  %    lastFrame = fileFrameIdx.last(n);
  nSubFrames = tifFile(n).nFrames;
  for ksf = 1:nSubFrames
	 multiWaitbar(wbString, 'Increment', 1/nTotalFrames);
	 kFrame = fileFrameIdx.first(n) + ksf - 1;
	 data(:,:,kFrame) = tifObj.read();
	 if tifObj.lastDirectory()
		break
	 else
		tifObj.nextDirectory();
	 end
  end
  close(tifObj);
end
% tProc = hat - tProc;
% fprintf([mfilename, ':\t Loaded %i frames in %3.4g seconds \t(%3.4g ms/frame\n\n'],...
%    1000*tProc/nTotalFrames);
multiWaitbar(wbString, 'Close')
if nargout > 1
  varargout{1} = info;
  if nargout > 2
	 varargout{2} = tifFile;
  end
end
end
function [data, pre] = homomorphicFilter(data,pre)
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
% gpu = gpuDevice(1);
% CONSTRUCT HIGH-PASS (or Low-Pass) FILTER
sigma = 50;
filtSize = 2 * sigma + 1;
hLP = gpuArray(fspecial('gaussian',filtSize,sigma));
% GET RANGE FOR CONVERSION TO FLOATING POINT INTENSITY IMAGE
if nargin < 2
  %    pre.dmax = getNearMax(data); %TODO: move into file as subfunction
  %    pre.dmin = getNearMin(data);
  pre.dmax = max(data(:));
  pre.dmin = min(data(:));
end
inputScale = single(pre.dmax - pre.dmin);
inputOffset = single(pre.dmin);
outputRange = [0 65535];
outputScale = outputRange(2) - outputRange(1);
outputOffset = outputRange(1);
% PROCESS FRAMES IN BATCHES TO AVOID PAGEFILE SLOWDOWN??TODO?
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
fprintf('Correcting Motion \n')
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
  % APPLY OFFSET TO FRAME
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
stat.Range = range(data, 3);
stat.Min = min(data, [], 3);
win.filtSize = min(winsize)/2;
imRobust = double(imfilter(rangefilt(stat.Min),fspecial('average',win.filtSize))) ./ double(imfilter(stat.Range, fspecial('average',win.filtSize)));
gaussmat = gauss2d(sz(1), sz(2), sz(1)/2.5, sz(2)/2.5, sz(1)/2, sz(2)/2);
gaussmat = gaussmat * (mean2(imRobust) / max(gaussmat(:)));
imRobust = imRobust .*gaussmat;
imRobust = imRobust(win.rowSubs, win.colSubs);
[~, maxInd] = max(imRobust(:));
[win.rowMax, win.colMax] = ind2sub([length(win.rowSubs) length(win.colSubs)], maxInd);
win.rowMax = win.rowMax + win.edgeOffset(1);
win.colMax = win.colMax + win.edgeOffset(2);
win.rows = win.rowMax-winsize(1)/2+1 : win.rowMax+winsize(1)/2;
win.cols = win.colMax-winsize(2)/2+1 : win.colMax+winsize(2)/2;
winRectangle = [win.cols(1) , win.rows(1) , win.cols(end)-win.cols(1) , win.rows(end)-win.rows(1)];
end
function data = spatialFilter(data)
[nRows,nCols,nFrames] = size(data);
filtType = 'gauss';
switch filtType
  case 'med'
	 fprintf('Applying 2D Median Filter \n')
	 medFiltSize = [3 3];
	 for k=1:nFrames
		data(:,:,k) = gather(medfilt2(gpuArray(data(:,:,k)), medFiltSize));
	 end
  case 'gauss'
	 h = fspecial('gaussian',[5 5], .8);
	 data = imfilter(data, h, 'replicate');
end
end
function [data, pre] = normalizeData(data, pre)
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
N = size(data,3);
data = bsxfun( @minus, data+1024, imclose(pre.fmin, strel('disk',5)));
fprintf('\t Post-Min-Subtracted MINIMUM: %i\n',min(data(:)))
fprintf('\t Post-Min-Subtracted MAXIMUM: %i\n',max(data(:)))
fprintf('\t Post-Min-Subtracted RANGE: %i\n',range(data(:)))
fprintf('\t Post-Min-Subtracted MEAN: %i\n',mean(data(:)))

% SEPARATE ACTIVE CELLULAR AREAS FROM BACKGROUND (NEUROPIL)
if nargin < 2
  activityImage = imfilter(range(data,3), fspecial('average',101), 'replicate');
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
  pre.scaleval = 65535/double(1.1*getNearMax(data));
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
function data = subtractRail2RailNoise(data)
% SUBTRACT RANGEFILTERED DATA TO LIMIT MOTION INDUCED NOISE
% rfDataMean = int32(floor( mean(rangefilt(data, true([5 5 3])),3))); % 6.5 min (3,3,5) vs. 31 sec (3,3,3) vs. 5min (5,5,3)
data = data - min(data(:));
rfDataMean = imfilter(single(fastRangeFilt3(data, 20, 9)), fspecial('gaussian',[9 9], 1.5), 'replicate');
% rfDataMean = imfilter(imdilate(single(fastRangeFilt3(data, 20, 9)), strel('disk',1)), fspecial('gaussian',[9 9], 1.5), 'replicate');
rfSubOffset = single(mean(rfDataMean(:)));
data =  bsxfun(@minus, single(data) + rfSubOffset, rfDataMean ); % 2min
% rfSubOffset = min(rfDataMean(:));
% data = uint16(bsxfun(@minus, int32(data) + rfSubOffset, rfDataMean)); % 2min
end
function rfDataMean = fastRangeFilt3(data, nTemp, nSpat)
if nargin < 2
  nTemp = 5;
end
if nargin < 3
  nSpat = 5;
end
[nrows, ncols, N] = size(data);
inputDataType = class(data);
% ON-PHASE
nChunk1 = floor(N/nTemp);
data1 = permute(reshape( data(:,:,1:nChunk1*nTemp), nrows, ncols, nTemp, []), [3 1 2 4]);
cdata1 = imfilter(single(squeeze(range(data1, 1))), fspecial('average',nSpat), 'replicate');
rfMean1 = mean(cdata1,3);
% OFF-PHASE
offset = ceil(nTemp/2);
nChunk2 = floor((N-offset)/nTemp);
data2 = permute(reshape( data(:,:,offset+1:nChunk2*nTemp+offset), nrows, ncols, nTemp, []), [3 1 2 4]);
cdata2 = imfilter(single(squeeze(range(data2, 1))), fspecial('average',nSpat), 'replicate');
rfMean2 = mean(cdata2,3);
rfDataMean = cast( .5*rfMean1 + .5*rfMean2, inputDataType);
end
function [data, lastFrame] = subtractBaseline(data, lastFrame)
if nargin < 2
  lastFrame = [];
end						% Data may be approximately between (.5, 1.75)
fprintf('Subtracting Baseline \n')
% SUBTRACT RESULTING BASELINE THAT STILL EXISTS IN NEUROPIL
% dataRange = range(data(:));
% imFloor =  getNearMin(data) - lowBuf;
% fprintf('\t->Adding %3.3g to input\n', -imFloor)
% data = data - imFloor;
activityImage = imfilter(range(data,3), fspecial('average',201), 'replicate');
npMask = double(activityImage) < median(activityImage(:));
npPixNum = sum(npMask(:));
npBaseline = sum(sum(bsxfun(@times, data, cast(npMask,'like',data)), 1), 2) ./ npPixNum; %average of pixels in mask
cellMask = ~npMask;
cellPixNum = sum(cellMask(:));
cellBaseline = sum(sum(bsxfun(@times, data, cast(cellMask,'like',data)), 1), 2) ./ cellPixNum;
% npBaseline = npBaseline(:);
baselineOffset = log(mean(cellBaseline(:))+1);
data = cast( exp( bsxfun(@minus,...
  log(single(data)+1) + baselineOffset,...
  log(single(npBaseline)+1))) - 1, 'like', data) - 1;
% REMOVE BASELINE SHIFTS BETWEEN FRAMES (TODO: untested, maybe move to subtractBaseline)
if ~isempty(lastFrame)
  firstFrame = median(data(:,:,1:8), 3);
  interFileDif = single(firstFrame) - single(lastFrame);
  fileRange = range(data,3);
  baselineShift = double(mode(interFileDif(fileRange < median(fileRange(:)))));
  fprintf('\t->Applying baseline-shift: %3.3g\n',-baselineShift)
  data = data - baselineShift;
end
lastFrame = median(data(:,:,end-7:end), 3);

end
function [data, varargout] = tempAndSpatialFilter(data,fps,varargin)

% pnrf = rangefilt(data, true([3 3 5])); % 6.5 minutes if [3 3 5], 31 sec if [3 3 3]
% data = bsxfun(@minus, data, mean(pnrf,3,'native')); % 2min

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
minRoiPixArea = 30; %previously 50
maxRoiPixArea = 150; %previously 350, then 650, then 250
maxRoiEccentricity = .93;%previously .92
maxPerimOverSqArea = 6; %  circle = 3.5449, square = 4 % Previousvalues: [6.5  ]
minPerimOverSqArea = 3.0; % previously 3.5
% INITIALIZE DYNAMIC SIGNAL THRESHOLD ARRAY: ~1 STD. DEVIATION OVER MINIMUM (OVER TIME)
stdOverMin = 1.3; % formerly 1.2
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
	 coverageMinPixels = 300; % previous values: 500, 250
	 thresholdStep = 1;
	 % PREVENT RACE CONDITION OR NON-SETTLING THRESHOLD
	 persistent depth
	 if isempty(depth)
		depth = 0;
	 else
		depth = depth + 1;
		% 		 thresholdStep = 1 + depth;
	 end
	 recursionLim = 250;
	 if depth > recursionLim
		warning('Recursion limit exceeded')
		depth = 0;
		bw = false(size(diffImage));
		sigThresh = gpuArray( stat.Min + uint8( stat.Std.*stdOverMin ));% NEW, (reset)
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






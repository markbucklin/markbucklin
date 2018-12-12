function [data, varargout] = process2PhotonData(varargin)

if nargin > 0
   [fdir, uniqueFileName, fext] = fileparts(varargin{1});
else
   fdir = pwd;
   uniqueFileName = 'Data12';
end

% CONSTANTS
nFramesPerTrial = 113;

% LOAD
[data, info, tifFile] = loadTif([uniqueFileName,'.tif']);
sz = size(data);

% HOMOMORPHIC FILTER
pre.homofilt = data;
data = homomorphicFilter(data, 20);

% MOTION CORRECTION
pre.motioncorrection = data;
prealign.cropBox = [1 1 size(data,2), size(data,1)];
prealign.n = 0;
[data, xc, prealign] = correctMotion2Photon(data, prealign);
pre.processrecord.xc = xc;
pre.processrecord.prealign = prealign;

% REMOVE UNCORRECTABLE FRAMES (Z-AXIS MOTION)
pre.freezeframes = data;
mot = hypot(xc.xoffset, xc.yoffset);
freezeframes = find(mot>1);
for k=1:nFramesPerTrial
   data(:,:,freezeframes) = data(:,:,freezeframes-1);
end

% SPATIAL FILTER
pre.spatialfilter = data;
h = fspecial('gaussian',[5 5], .8);
data = imfilter(data,h,'replicate');

% TEMPORAL FILTER
pre.tempsmooth = data;
fps = 20;
fnyq = fps/2;
n = 50;
fstop = 5.5; %Hz
dLowPass = designfilt('lowpassfir','SampleRate',fps, 'PassbandFrequency',fstop-.5, ...
   'StopbandFrequency',fstop+.5,'PassbandRipple',0.5, ...
   'StopbandAttenuation',90,'DesignMethod','kaiserwin');%could also use butter,cheby1/2,equiripple
tdata = reshape(data, sz(1), sz(2), 113, []);
for k=1:size(tdata,4)
   tdata(:,:,:,k) = temporalFilter(tdata(:,:,:,k), dLowPass);
end
try
   data = reshape(tdata,sz(1), sz(2), []);
catch me
   keyboard
end

% NORMALIZE
try
   pre.normalize = data;
   [data, pre.processrecord.norm] = normalizeData2Photon(data);
catch me
   keyboard
end

% FIND ROIs
d8a = uint8(single(data)*(255/65535));
roi = detectSingleFrameRois(d8a);
R = reduceSuperRegions(roi,15);
X = makeTraceFromVid(R,pre.tempsmooth);
normalizeRoiTrace2WindowedRange(R);
save(fullfile(fdir,roiFileName), 'R');

% vfile = saveVidFile(d8a,info, tifFile(1));
% allVidFiles = VideoFile.empty(nFiles,0);
% allVidFiles(1) = vfile;
%
% % ------------------------------------------------------------------------------------------
% % ONCE VIDEO HAS BEEN PROCESSED - CREATE FILENAMES AND SAVE VIDEO
% % ------------------------------------------------------------------------------------------
% uniqueFileName = procstart.commonFileName;
saveTime = now;
processedVidFileName =  ...
   ['Processed_Video_',...
   uniqueFileName,'_',...
   datestr(saveTime,'yyyy_mm_dd_HHMM'),...
   '.mat'];
% processedStatsFileName =  ...
%    ['Processed_VideoStatistics_',...
%    uniqueFileName,'_',...
%    datestr(saveTime,'yyyy_mm_dd_HHMM'),...
%    '.mat'];
% processingSummaryFileName =  ...
%    ['Processing_Summary_',...
%    uniqueFileName,'_',...
%    datestr(saveTime,'yyyy_mm_dd_HHMM'),...
%    '.mat'];
roiFileName = ...
   ['Processed_ROIs_',...
   uniqueFileName,'_',...
   datestr(saveTime,'yyyy_mm_dd_HHMM'),...
   '.mat'];
% save(fullfile(fdir, processedVidFileName), 'allVidFiles');
% save(fullfile(fdir, processedStatsFileName), 'vidStats', '-v6');
% save(fullfile(fdir, processingSummaryFileName), 'vidProcSum', '-v6');
% % ------------------------------------------------------------------------------------------
% % MERGE/REDUCE REGIONS OF INTEREST
% % ------------------------------------------------------------------------------------------
% singleFrameRoi = fixFrameNumbers(singleFrameRoi);
% saveRoiExtract(singleFrameRoi,fdir)
% R = reduceRegions(singleFrameRoi);
% R = reduceSuperRegions(R);
% % ------------------------------------------------------------------------------------------
% % SAVE TOP 1000 ROIs ACCORDING TO 'FrameDifferenceSum' INDEX
% % ------------------------------------------------------------------------------------------
% fds = zeros(numel(R),1);
% for k=1:numel(R)
%    fds(k,1) = sum(diff(R(k).Frames) == 1) / sum(diff(R(k).Frames) > 2);
% end
% save('allROI','R')
% fdsmin = 1;
% while sum(fds >= fdsmin) > 1000
%    fdsmin = fdsmin + .1;
% end
% R = R(fds >= fdsmin);
% % ------------------------------------------------------------------------------------------
% % RELOAD DATA AND MAKE ROI TRACES (NORMALIZED TO WINDOWED STD)
% % ------------------------------------------------------------------------------------------
% [data, vidinfo] = getData(allVidFiles);
% data = squeeze(data);
% X = makeTraceFromVid(R,data);
% fs=20;
% winsize = 1*fs;
% numwin = floor(size(X,1)/winsize)-1;
% xRange = zeros(numwin,size(X,2));
% for k=1:numwin
%    windex = (winsize*(k-1)+1):(winsize*(k-1)+20);
%    xRange(k,:) = range(detrend(X(windex,:)), 1);
% end
% X = bsxfun(@rdivide, X, mean(xRange,1));
% for k=1:numel(R)
%    R(k).Trace = X(:,k);
% end
save(fullfile(fdir,roiFileName), 'R');
save(fullfile(fdir,processedVidFileName), 'd8a', '-v6');
% end







% OUTPUT
if nargout > 1
   varargout{1} = pre;
end

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







end
function roi = detect2PhotonRois(data,info)
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
stat.Min = min(data,[],3);
stat.Std = std(double(data),1,3);
minRoiPixArea = 50; %previously 50
maxRoiPixArea = 300; %previously 350, then 650, then 250
maxRoiEccentricity = .93;%previously .92
maxPerimOverSqArea = 6; %  circle = 3.5449, square = 4 % Previousvalues: [6.5  ]
minPerimOverSqArea = 3.0; % previously 3.5
% INITIALIZE DYNAMIC SIGNAL THRESHOLD ARRAY: ~1 STD. DEVIATION OVER MINIMUM (OVER TIME)
stdOverMin = 1.2; % formerly 1.2
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
	  coverageMaxRatio = .05; %  .01 = 10K pixels (15-30 cells?)
	  % 	  coverageMinPixels = 300; % previous values: 500, 250
	  coverageMinRatio = .005;
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
	  elseif binaryCoverage < coverageMinRatio
		 sigThresh = sigThresh - thresholdStep;
		 [bw, sigThresh]  = getAdaptiveHotspots(diffImage, sigThresh);
	  else
		 depth = 0;
	  end
   end

end
function [data, pre] = normalizeData2Photon(data, pre)
fprintf('Normalizing Fluorescence Signal \n')
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
data = bsxfun( @minus, data+1024, imclose(pre.fmin, strel('disk',3)));
fprintf('\t Post-Min-Subtracted MINIMUM: %i\n',min(data(:)))
fprintf('\t Post-Min-Subtracted MAXIMUM: %i\n',max(data(:)))
fprintf('\t Post-Min-Subtracted RANGE: %i\n',range(data(:)))
fprintf('\t Post-Min-Subtracted MEAN: %i\n',mean(data(:)))

% SEPARATE ACTIVE CELLULAR AREAS FROM BACKGROUND (NEUROPIL)
if nargin < 2
   activityImage = imfilter(range(data,3), fspecial('average',31), 'replicate');
   pre.npMask = double(activityImage) < mean2(activityImage);
   pre.npPixNum = sum(pre.npMask(:));
   pre.cellMask = ~pre.npMask;
   pre.cellPixNum = sum(pre.cellMask(:));
end
pre.npBaseline = sum(sum(bsxfun(@times, data, cast(pre.npMask,'like',data)), 1), 2) ./ pre.npPixNum; %average of pixels in mask
pre.cellBaseline = sum(sum(bsxfun(@times, data, cast(pre.cellMask,'like',data)), 1), 2) ./ pre.cellPixNum;

% REMOVE BASELINE SHIFTS TO STABILIZE GROUP MEDIAN

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

end














function vid8bit = processVid(varargin)

% myCluster = parcluster('local');
%% PROCESS FILENAME INPUT OR QUERY USER FOR MULTIPLE FILES
if nargin
  fname = varargin{1};
  for n = 1:numel(fname)
	 fileName{n} = which(fname{n});
  end
else
  [fname,fdir] = uigetfile('*.tif','MultiSelect','on');
  switch class(fname)
	 case 'char'
		fileName{1} = [fdir,fname];
	 case 'cell'
		for n = 1:numel(fname)
		  fileName{n} = [fdir,fname{n}];
		end
  end
end

% GET INFO FROM EACH TIF FILE
for n = 1:numel(fileName)
  tifFile(n).fileName = fileName{n};
  tifFile(n).vidInfo = imfinfo(fileName{n});
  tifFile(n).nFrames = numel(tifFile(n).vidInfo);
end
nTotalFrames = sum([tifFile(:).nFrames]);
lastFrameIndices = cumsum([tifFile(:).nFrames]);
firstFrameIndices = [0 lastFrameIndices(1:end-1)]+1;
filePath = fileparts(tifFile(1).fileName);
vidHomFilt = [];
vidMean = [];

%% LOAD FILES INDIVIDUALLY FOR HIGH-BITDEPTH CALCULATIONS
for kFile = 1:numel(tifFile)
  % LOAD TIFF FILE
  vid = loadTif(tifFile(kFile).fileName); %23-38ms/f [uint16]
  % vid = loadTifPar; %40fps loading 4 files
  N = numel(vid);
  
  % PRE-FILTER WITH FAST HOMOMORPHIC FILTER (REMOVE UNEVEN ILLUMINATION)
  if kFile == 1
	 vidHomFilt = generateHomomorphicFilters(vid);
	 cropBox = getRobustWindow(vid, 100);
  end
  vid = applyHomomorphicFilters(vid, vidHomFilt);	%	6ms/f	[single]
  firstFrameNumber = firstFrameIndices(kFile);
  lastFrameNumber = lastFrameIndices(kFile);
  % CROP VIDEO FOR MOTION CORRECTION
  croppedVid = arrayfun(@(x)(imcrop(x.cdata, cropBox)), vid, 'UniformOutput',false);
  vidFields = fields(vid);
  for k = 1:numel(vidFields)
	 fieldName = vidFields{k};
	 if strcmpi('cdata',fieldName)
		% 		[vidAllCropped(firstFrameNumber:lastFrameNumber).cdata] = deal(croppedVid{:});
		[vidCropped.cdata] = deal(croppedVid{:});
	 else
		% 		[vidAllCropped(firstFrameNumber:lastFrameNumber).(fieldName)] = deal(vid.(fieldName));
		[vidCropped.(fieldName)] = deal(vid.(fieldName));
	 end
  end
  vidLast = vid;
  if isempty(vidMean)
	 % 	 [frameOffset(firstFrameNumber:lastFrameNumber), vidMean] = alignVid2Mean(vidAllCropped);
	 alignFcn = @(crvid)(alignVid2Mean(crvid));
	 j = batch(alignFcn, 2, {vidCropped})
  else
	 % 	 [frameOffset(firstFrameNumber:lastFrameNumber), vidMean] = alignVid2Mean(vidAllCropped, vidMean);
	 alignFcn = @(crvid,crtemplate)(alignVid2Mean(crvid, crtemplate));
	 wait(j)
	 jout = j.fetchOutputs;
	 xc = jout{1};
	 template = jout{2};
	 jApply = batch(applyFcn, 2, {vidCropped})
  end
end
%% MOTION CORRECTION

% mcOffsets = alignVidRecursive(vidAllCropped);







%% CORRECT FOR MOTION (IMAGE STABILIZATION)
% 		motCorPoints = 5;
% 		frameSize = size(vid(1).cdata);
% 		templateSize = round(frameSize./20);
% 		templateLoc = round(frameSize/4 - templateSize/2);
% 		bb1 = [templateLoc templateSize];
% 		bb2 = [frameSize-templateLoc-templateSize templateSize];
% 		c(1).BoundingBox = bb1;
% 		c(2).BoundingBox = bb2;
% 		c(3).BoundingBox = [bb1(1) bb2(2:4)];
% 		c(4).BoundingBox = [bb2(1) bb1(2:4)];
% 		assignin('base','vid',vid)
% 		keyboard
% 		c = highEntropyCentroids(vid, 1);
% 		for kMot = 1:numel(c)
xc = generateXcOffset(vid, cropBox);%, c(kMot).BoundingBox);
% 		end
% 		[~,xStable] = min(range(reshape([xc.xoffset],[],kMot)));
% 		[~,yStable] = min(range(reshape([xc.yoffset],[],kMot)));
% 		if xStable ~= yStable
% 		  xcx = xc(:,xStable);
% 		  xcy = xc(:,yStable);
% 		  keyboard
%
% 		end
vid = applyXcOffset(vid,xc); %	8ms/f












%% POST-FILTER WITH SLOW HOMOMORPHIC FILTER (MOTION-INDUCED ILLUMINATION)
vid = slowHomomorphicFilter(vid); %	27ms/f

%%	DIFFERENCE IMAGE
% 		vid = tempSmoothVidStruct(vid, 5);
impc = prctile(cat(3,vid(round(linspace(1,N,min(300,N)))).cdata),1:100,3);
vid = generateDifferenceImage(vid,impc);


firstFrameNumber = firstFrameIndices(kFile);
lastFrameNumber = lastFrameIndices(kFile);
vid8bit(firstFrameNumber:lastFrameNumber) = vidStruct2uint8(vid);



%% NORMALIZE EACH FRAME TO BASELINE AREAS WITH LOWEST TEMPORAL VARIANCE
stat = getVidStats(vid8bit);
lowVarianceMask = and(...
  imerode(stat.Var < 2*min(stat.Var(:)), strel('disk', 5, 8)),...
  imerode(stat.Min < .5*max(stat.Min(:)), strel('disk', 5, 8)));
maskCoverage = sum(lowVarianceMask(:))./sum(~lowVarianceMask(:));
if (maskCoverage > .01) && (maskCoverage < .20)
  vid8bit = normalizeVidStruct2Region(vid8bit, lowVarianceMask);
else
  vid8bit = normalizeVidStruct2Region(vid8bit); %	query user to select regions
end

%% TEMPORALLY SMOOTH 8-BIT OUTPUT
vid8bit = tempSmoothVidStruct(vid8bit, 2);

%% RETURN STRUCTURE
if nargout < 1
  assignin('base', 'vid',vid8bit)
end







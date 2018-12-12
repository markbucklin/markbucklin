function vid = processVid2Striatum()
%% PROCESS FILENAME INPUT OR QUERY USER FOR MULTIPLE FILES
% if nargin
%   fname = varargin{1};
%   for n = 1:numel(fname)
% 	 fileName{n} = which(fname{n});
%   end
% else
%   [fname,fdir] = uigetfile('*.tif','MultiSelect','on');
%   switch class(fname)
% 	 case 'char'
% 		fileName{1} = [fdir,fname];
% 	 case 'cell'
% 		for n = 1:numel(fname)
% 		  fileName{n} = [fdir,fname{n}];
% 		end
%   end
% end
%
% % GET INFO FROM EACH TIF FILE
% for n = 1:numel(fileName)
%   tifFile(n).fileName = fileName{n};
%   tifFile(n).vidInfo = imfinfo(fileName{n});
%   tifFile(n).nFrames = numel(tifFile(n).vidInfo);
% end
% nTotalFrames = sum([tifFile(:).nFrames]);
% lastFrameIndices = cumsum([tifFile(:).nFrames]);
% firstFrameIndices = [0 lastFrameIndices(1:end-1)]+1;
% filePath = fileparts(tifFile(1).fileName);
prealign = [];
impc = [];

% for nfile = 1:numel(tifFile)
try
  %% LOAD TIFF FILE
  vid = loadTif;  %(tifFile(nfile).fileName); %38ms/f
  % vid = loadTifPar; %40fps loading 4 files
  N = numel(vid);
  
  %% CROP THE VIDEO IF NECESSARY
  needToCrop = true;
  if needToCrop
	 vid = cropVidStruct(vid);
  end
  
  
  %% PRE-FILTER WITH FAST HOMOMORPHIC FILTER (REMOVE UNEVEN ILLUMINATION)
  % % 		vidHomFilt = generateHomomorphicFilters(vid);
  % 	 if nfile == 1
  vidHomFilt = generateHomomorphicFilters(vid);
  % 	 end
  vid = applyHomomorphicFilters(vid, vidHomFilt);	%	6ms/f
  
  %% STRIATUM-SPECIFIC DIFFERENCE OF GAUSSIAN SPATIAL FILTER
  vid = filterStriatalVid(vid);
catch me
  fprintf('%s\n',me.message);
  keyboard
end
try
  
  %% CORRECT FOR MOTION (IMAGE STABILIZATION)
  
  if isempty(prealign)
	 [vid, xc, prealign] = alignVid2Mean(vid);
  else
	 [vid, xc, prealign] = alignVid2Mean(vid, prealign);
  end
catch me
  fprintf('%s\n',me.message);
  keyboard
end
try
  
  % 	 fAlign = @(v,s)( circshift(v.cdata, -[s.xoffset, s.yoffset]));
  % 	 vida = arrayfun(fAlign,vid,xc);
  % 	 vid = applyXcOffset(vid,xc); %	8ms/f
  
  %% POST-FILTER WITH SLOW HOMOMORPHIC FILTER (MOTION-INDUCED ILLUMINATION)
  % 	 vid = slowHomomorphicFilter(vid); %	27ms/f
  % the slow homomorphic filter could be implemented (but in the current state the output is entirely
  % zeros)
  
  %%	DIFFERENCE IMAGE
  % 		vid = tempSmoothVidStruct(vid, 5);
  % 	 if isempty(impc)
  % 		impc = prctile(cat(3,vid(round(linspace(1,N,min(300,N)))).cdata),1:100,3);
  %     impc = prctile(double(cat(3,vid(round(linspace(1,N,min(300,N)))).cdata)),1:100,3);
  % 	 end
  % 	 vid = generateDifferenceImage(vid,impc);
  
  
  % 	 firstFrameNumber = firstFrameIndices(nfile);
  % 	 lastFrameNumber = lastFrameIndices(nfile);
  inputRange = [1000 4500];
  vid8 = vidStruct2Uint8Ranged(vid, inputRange);
  % 	 [vidxc(firstFrameNumber:lastFrameNumber).xc] = deal(xc);
catch me
  fprintf('%s\n',me.message);
  keyboard
end
% end

%% NORMALIZE EACH FRAME TO BASELINE AREAS WITH LOWEST TEMPORAL VARIANCE
% try
%   stat = getVidStats(vid8bit);
%    lowVarianceMask = imerode(stat.Std < median(stat.Std(:)), strel('disk', 5, 8));
% %   lowVarianceMask = and(...
% % 	 imerode(stat.Std < 2*min(stat.Std(:)), strel('disk', 5, 8)),...
% % 	 imerode(stat.Min < .5*max(stat.Min(:)), strel('disk', 2, 8)));
%   maskCoverage = sum(lowVarianceMask(:))./sum(~lowVarianceMask(:));
%   if (maskCoverage > .01) && (maskCoverage < .80)
% 	 vid8bit = normalizeVidStruct2Region(vid8bit, lowVarianceMask);
%   else
% 	 keyboard
% 	 vid8bit = normalizeVidStruct2Region(vid8bit); %	query user to select regions
%   end
% catch me
%   keyboard
% end

%% TEMPORALLY SMOOTH 8-BIT OUTPUT
% keyboard
vid8 = tempSmoothVidStruct(vid8, 1);

%% GENERATE ROIS
% ROI = generateRegionsOfInterest(vid8bit);
% assignin('base', 'roi',ROI)%TODO
% stat = getVidStats(vid);
% [centers,radii] = imfindcircles(stat.Max,[6 25], 'Sensitivity', .9);
% cellMask = circleCenters2Mask(centers, radii, size(vid(1).cdata));

%% RETURN STRUCTURE
if nargout < 1
  assignin('base', 'vid',vid8)
  %   assignin('base', 'roi',ROI)
end







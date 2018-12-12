function vid = processVid2Striatum()
%% PROCESS FILENAME INPUT OR QUERY USER FOR MULTIPLE FILES

prealign = [];
impc = [];
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
  vidHomFilt = generateHomomorphicFilters(vid);
  vid = applyHomomorphicFilters(vid, vidHomFilt);	%	6ms/f
  %% STRIATUM-SPECIFIC DIFFERENCE OF GAUSSIAN SPATIAL FILTER
  vid = filterStriatalVid(vid);
catch me
  fprintf('%s\n',me.message);
  keyboard
end
  %% CORRECT FOR MOTION (IMAGE STABILIZATION)
try
  if isempty(prealign)
	 [vid, xc, prealign] = alignVid2Mean(vid);
  else
	 [vid, xc, prealign] = alignVid2Mean(vid, prealign);
  end
catch me
  fprintf('%s\n',me.message);
  keyboard
end
  %% POST-FILTER WITH SLOW HOMOMORPHIC FILTER (MOTION-INDUCED ILLUMINATION)
try
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
  inputRange = [1000 4500];
  keyboard
  vid8 = vidStruct2Uint8Ranged(vid, inputRange);
  % 	 [vidxc(firstFrameNumber:lastFrameNumber).xc] = deal(xc);
catch me
  fprintf('%s\n',me.message);
  keyboard
end
%% TEMPORALLY SMOOTH 8-BIT OUTPUT
% keyboard
vid8 = tempSmoothVidStruct(vid8, 1);
%% RETURN STRUCTURE
% if nargout < 1
  assignin('base', 'vid8',vid8)
  %   assignin('base', 'roi',ROI)
% end







% function roi = scrap2(dataDir)
%%

% load session.mat or run file to index data as SessionInfo object array

% currentDAT = 15;
% s = findobj(session,'MouseId','0419GE_M1RH')
% s = findobj(s,'FrameRate',40)
% currentSession = findobj(s, 'DayAfterTransplantation',currentDAT)


%%
% if nargin < 1, dataDir = pwd; end
dataDir = pwd;
cd(dataDir)
tif = dir('*.tif');

exportDir = fullfile('~/raid.data', 'export');
if ~isdir(exportDir)
  mkdir(exportDir); 
end
[cmd.status,cmd.result] = system(sprintf('chmod --recursive a+w %s', exportDir));    
    

%%
tiffLoader = scicadelic.TiffStackLoader(...
	'FileDirectory',dataDir,...
	'FileName', {tif.name});

tiffLoader.FramesPerStep = 1;

%%
writeGray = false;
writeRGB = false;
[nextFcn,pp] = getScicadelicPreProcessor(tiffLoader, writeGray, writeRGB);
assignin('base','nextFcn',nextFcn)
assignin('base','pp',pp)

%% Init for Pre-Run
red.thresh = {};
red.mask = {};
blue.thresh = {};
blue.mask = {};
numFrames = tiffLoader.NumFrames;
frameSize = tiffLoader.FrameSize;
numPixels = prod(frameSize);
frameIdx = 0;
numPreFrames = 1024; %ceil(numFrames/8);
numFramesPerChunk = tiffLoader.FramesPerStep;
numChunks = tiffLoader.NumSteps;
% pxl.red = scicadelic.PixelLabel;
% pxl.blue = scicadelic.PixelLabel;
PL = scicadelic.PixelLabel;
% DetectionStartDelay
% RegistrationStartDelay
SCq = scicadelic.StatisticCollector;
SCf = scicadelic.StatisticCollector;
SCft = scicadelic.StatisticCollector;
% errorFlag = false;

%% Pre-Run
while frameIdx(end) < numPreFrames
	[out.f,out.info,out.mstat,out.frgb,out.srgb] = nextFcn();
	% Update Index and Timestamp
	frameIdx = out.info.idx;
	t = out.info.timestamp;
	if t(1)>5
		
		% Update Statistics for Pre-Processed Image Pixel Intensity
		step(SCf, out.f);
		% 		if numel(t) > 1
		% 			ft_quickdirty = bsxfun( @rdivide, diff(out.f,[],3), reshape(diff(t),1,1,[]));
		% 			step(SCft, ft_quickdirty);
		% 		end
		
		% Get Pixel-Activation Metric Sources from Current Chunk
		pixelActivationSource = {...
			out.srgb.marginalKurtosisOfIntensity,...
			out.srgb.marginalSkewnessOfIntensityChange};
		
		% Fix NaNs -> 0
		for kq = 1:numel(pixelActivationSource)
			q = pixelActivationSource{kq};
			qNanMatch = isnan(q(:));
			if any(qNanMatch)
				q(qNanMatch) = 0;
				pixelActivationSource{kq} = q;
			end
		end
		
		% Combine Sources Using Customizable Function (default is max(Qa,Qb)
		combinationDim = max(cellfun(@ndims,pixelActivationSource)) + 1;
		combinationFcn = @(qs) max(qs, [], combinationDim);
		Qs = cat(combinationDim, pixelActivationSource{:});
		Q = combinationFcn(Qs);
		
		% Update Statistics of Activation Metric
		step(SCq, Q);
		
		% Submit Pixel-Activation Training Data (Update scicadelic.PixelLabel
		update( PL, Q);
		
	end
	% Update Visual with Max-Projection of Current Chunk
	fChunk = oncpu( uint8(max(out.frgb,[],4)));
	try
        if exist('hmp','var')
            hmp.CData = fChunk;
        else
            hmp = imshow(fChunk);
        end
        set(hmp.Parent.Title,...
            'String', sprintf('Time: % 22g seconds',t(end)),...
            'Color', [0 0 0]);
        drawnow update
	catch
		warning('failure to update visual')
	end
	
	
end


% TODO: save statistic collector outputs 



%% Specify Signals Extracted from Each Chunk --> {'signalname': source_variable}
getInputSignals = @(nextOut) struct(...
	'intensity', nextOut.f,...
	'red', nextOut.srgb.marginalKurtosisOfIntensity,...
	'blue', nextOut.srgb.marginalSkewnessOfIntensityChange);

%% Extract Label-Matrix & Region-Props from scicadelic.PixelLabel object
L = gather(PL.PrimaryRegionIdxMap);
roiIncludedPixelIdx = label2idx(L);
rp = regionprops(L,SCq.Mean,'all');
[reg.label, reg.pixelidx, reg.labelidx] = unique(L(:));


% TODO: curate rois


[seed.y, seed.x, seed.currentlabel] = find(PL.RegisteredRegionSeedIdxMap);
seed.pixelidx = sub2ind(frameSize, seed.y, seed.x);

%%
% %%
% seedIdxMap = gather(PL.RegisteredRegionSeedIdxMap);
% [roiSeed.pixelRow, roiSeed.pixelCol, roiSeed.regionIdx] = find(seedIdxMap);
% roiSeed.pixelIndex = sub2ind(frameSize, roiSeed.pixelRow, roiSeed.pixelCol)
%
%
% roiSeedPixelIdx = label2idx(seedIdxMap);
%
% numPixelIdx = cellfun( @numel, roiIncludedPixelIdx);
% roiIncludedPixelIdx = roiIncludedPixelIdx(numPixelIdx >= MIN_PIXEL_IDX_CNT);
% regProp2PixelLabelProp = struct(...
% 	'Area', PL.RegionArea',...
% 	'BoundingBox', 'RegionBoundingBox',...
% 	'Centroid', 'RegionCentroid');
%

% 	'Area', 'RegionArea',...
% 	'BoundingBox', 'RegionBoundingBox',...
% 	'Centroid', 'RegionCentroid')

% SHAPE MEASUREMENTS
%	  'Area'              'EulerNumber'       'Orientation'
%     'BoundingBox'       'Extent'            'Perimeter'
%     'Centroid'          'Extrema'           'PixelIdxList'
%     'ConvexArea'        'FilledArea'        'PixelList'
%     'ConvexHull'        'FilledImage'       'Solidity'
%     'ConvexImage'       'Image'             'SubarrayIdx'
%     'Eccentricity'      'MajorAxisLength'
%     'EquivDiameter'     'MinorAxisLength'
% PIXEL-VALUE MEASUREMENTS
%	  'MaxIntensity'
%     'MeanIntensity'
%     'MinIntensity'
%     'PixelValues'
%     'WeightedCentroid'

%% Define Functions for Extracting Pixel-Values from Each Chunk to form Traces
groupPixelsInIdxCell = @(f) cellfun( @(roiidx) gather(f(roiidx,:)'), roiIncludedPixelIdx, 'UniformOutput',false);
extractRoiPixelTrace = @(f) groupPixelsInIdxCell( reshape( f, numPixels, []));

% Map Pixels to ROIs
tmp = cellfun( @(pxidx,roiidx) ones(size(pxidx)) .* roiidx,...
	roiIncludedPixelIdx,...
	num2cell(1:numel(roiIncludedPixelIdx)),'UniformOutput',false);
idxMap.pixel = cat(1,roiIncludedPixelIdx{:});
idxMap.roi = cat(1,tmp{:});
pixelBatchMat = @(f) reshape( f, size(f,1)*size(f,2), []);


%% Reset Frame-Idx to Zero and Pre-Allocate
pixelTraceChunk = struct.empty(0,numChunks);
reset(tiffLoader);
frameIdx = 0;
batchIdx = 0;
batchOut = struct.empty(0,numChunks); % TODO: move up to Pre-Run

%% Saving
% save(sprintf('label matrix (%s)',strrep(datestr(now),':','_')),'L', '-v7.3','-nocompression')
imwrite(label2rgb(L), fullfile( exportDir, sprintf('label matrix (%s).png',strrep(datestr(now),':','_'))))
rgbFilenameBase = fullfile(exportDir, 'rgb');
saveRGB = @(f) writeBinaryData( oncpu(f), rgbFilenameBase, false);



%% Run Processing on All Frames with Trace Extraction for Each ROI
while frameIdx(end) < numFrames
	tStart = tic;
	[out.f, out.info, out.mstat, out.frgb, out.srgb] = nextFcn();
	if isempty(out.f)
		break
	end
	frameIdx = out.info.idx;
	t = out.info.timestamp;
	batchIdx = batchIdx + 1;	
	
	% Gather any Batch-Output that should be Preserved in Memory
	batchOut(batchIdx).info = out.info;
	
	% Save RGB
    saveRGB(out.frgb);
	
	% Extract Traces from Current Frames
	signal = getInputSignals(out);
	signalNames = fields(signal);
	for ksig = 1:numel(signalNames)
		name = signalNames{ksig};
		c = extractRoiPixelTrace( signal.(name) );
		pixelTraceChunk(batchIdx).(name) = c;
	end
	
	chunkDur = toc(tStart);
	fprintf('Frame %d to %d\t\t[%22g ms/frame]\n', frameIdx(1), frameIdx(end), 1000*chunkDur/numel(frameIdx));
end


%% Un-Chunkify Roi Pixel Traces -> save in 'roi' structure
numRegion = numel(roiIncludedPixelIdx);
roi = struct('idx',roiIncludedPixelIdx,'trace',cell(size(roiIncludedPixelIdx)));
roiPixelTrace = struct.empty(0,numRegion);
for k=1:numel(roi), roi(k).props = rp(k); end

for ksig = 1:numel(signalNames)
	name = signalNames{ksig};
	chunkedTrace = cat(1,pixelTraceChunk.(name));
	for k=1:numRegion
		roi(k).trace.(name) = cat(1,chunkedTrace{:,k});
	end
	chunkedTrace = {};
end

% pixelTraceChunk(:) = [];

%%


% Put Function Handle for Plotting in WOrkspace
roiPixelTracePlotFcn = getRoiPixelTracePlotFcn(roi);
assignin('base', 'roiPixelTracePlotFcn', roiPixelTracePlotFcn)


%% Get Noise Distribution by Sampling Randomly Selected Pixels from SCf and SCq

keyboard

% ---> Instead use 'getRoiPixelTracePlotFcn.m'


% end



function [thresh,maskidx] = getRoiMask(f)
[ny,nx,nt] = size(f);
[autoThresh,metric] = graythresh( gather(max(f,[],3)));
mask = bsxfun( @gt, f, autoThresh);
f(~mask) = 0;
[rowidx,colidx,fxy] = find(f);
offsetidx = floor(colidx/nt);
colidx = mod( colidx-1, nx) + 1;
maskidx.row = gather(rowidx);
maskidx.col = gather(colidx);
maskidx.offset = gather(offsetidx);
maskidx.f = gather(fxy);
thresh.level = gather(autoThresh);
thresh.metric = gather(metric);
end


function roi = getSingleFrameRegions(src)

f = accumarray([src.row, src.col, src.offset+1 ],...
	double(src.f),...
	[frameSize, max(src.offset)+1], @sum, 0, false);
Fmask = applyFunction2D( @bwareaopen, Fmask, 8);
Fmask = applyFunction2D( @bwmorph, Fmask, 'close');
end









%% From susie's rampage
% [Fglut, mot, dstat, procGlut] = feedFrameChunk(procGlut);
% % Fsmooth = gaussFiltFrameStack(F, 3);
% Fsmooth = gaussFiltFrameStack(Fglut, 1.5);
% Rglut = computeLayerFromRegionalComparisonRunGpuKernel(Fglut, [], [], Fsmooth);
% % [R,Rmean,Rvar] = computeLayerFromRegionalComparisonRunGpuKernel(F, [], [], Fsmooth);
% Rsmooth = gaussFiltFrameStack(Rglut, 1.5);
% peakMask = any(Fsmooth>0, 3);
% 
% 
% [S, B, bStability] = computeBorderDistanceRunGpuKernel(Rglut); 
% S0 = mean(S,3);
% B0 = mean(B,3);
% bStableCount = sum(bStability,3);
% 
% T = findLocalPeaksRunGpuKernel(S, peakMask);
% 
% % s = computeSurfaceCharacterRunGpuKernel(Fsmooth);
% % peakiness = max(0, max(0,-s.H).* s.K);
% % peakinessCutoff = median(peakiness(peakiness>0));
% % peakiness = 1 - 1./(sqrt(1 + (peakiness.^2)./(peakinessCutoff^2)));
% % T2 = findLocalPeaksRunGpuKernel(peakiness, peakMask);
% % roundedPeakMask = min(peakiness,[],3)>0;
% % T3 = findLocalPeaksRunGpuKernel(peakiness, roundedPeakMask);
% 
% % imcomposite(cat(3, max(0,mean(Fsmooth,3)), max(0,mean(R,3)), mean(log1p(abs(dstat.M4)),3)), mean(s.H<0&s.K>0,3)>.5, mean(B,3)>.1, mean(peakiness>.6,3)>.5)
% 
% % k12 = sqrt(s.k1.^2 + s.k2.^2);
% % k1Norm = s.k1 ./ k12;
% % k2Norm = s.k2 ./ k12;
% % inclusionMask =  (s.H<0) & (s.K>0) & (R>0);
% 
% [k1,k2,w1] = structureTensorEigDecompRunGpuKernel(Rsmooth); % or Fsmooth
% H = (k1+k2)/2;
% K = k1.*k2;
% inclusionMask =  (H<=0) & (K>=0) & (Rglut>0 | Rsmooth>0);
% [Sh, Bh, bhStability] = computeBorderDistanceRunGpuKernel(-H); % might as well change to be matrix
% Th = findLocalPeaksRunGpuKernel(Sh, peakMask);
% 
% edgeishness = B~=0 & Bh~=0;
% 
% peakiness = max(0, (-min(0,H)) .* K);
% peakinessCutoff = median(peakiness(peakiness>0));
% peakiness = 1 - 1./(sqrt(1 + (peakiness.^2)./(peakinessCutoff^2)));
% T2 = findLocalPeaksRunGpuKernel(peakiness, peakMask);
% roundedPeakMask = min(peakiness,[],3)>0;
% T3 = findLocalPeaksRunGpuKernel(peakiness, roundedPeakMask);



%%
% while ~isempty(idx) && (idx(end) < Nglut)
% 	
% 	
% 	
% 	[Fglut, idx] = procGlut.tl.step();	
% 	try
% 		Fglut = step(procGlut.mf, Fglut);
% 	catch
% 		disp('mf fail')
% 		Fglut =  hybridMedianFilterRunGpuKernel(Fglut);
% 	end
% 	Fglut = step(procGlut.ce, Fglut);
% 	dstat = step(procGlut.sc, Fglut);
% 		
% 	
% 	% 	[Fglut, mot, dstat, procGlut] = feedFrameChunk(procGlut);
% 	Fsmooth = gaussFiltFrameStack(Fglut, 1);
% 	Rglut = computeLayerFromRegionalComparisonRunGpuKernel(Fglut, [], [], Fsmooth);
% 	Rsmooth = gaussFiltFrameStack(Rglut, 1);
% 	idx = oncpu(idx(idx <=Nglut));	
% 	% 	dMotMag(idx) = gather(mot.dmag);
% 	Fcpu(:,:,idx) = gather(Fglut);
% 	Rcpu(:,:,idx) = gather(Rsmooth);
% 	dm1(:,:,idx) = gather(dstat.M1);
% 	dm2(:,:,idx) = gather(realsqrt(dstat.M2));
% 	dm3(:,:,idx) = gather(sslog(dstat.M3));
% 	dm4(:,:,idx) = gather(sslog(dstat.M4));	
% 	
% end
% % 	Fmean = gather(procGlut.sc.Mean);
% % 	Fmin = gather(procGlut.sc.Min);
% % 	Fstd = gather(procGlut.sc.StandardDeviation);
% % 	Fvar = gather(procGlut.sc.Variance);
% % 	
% % 	gcActivity = gather(dm1);
% % 	if ~exist('gcActivityMax','var')
% % 		% 		gcActivityMax = stackMax(abs(gcActivity));
% % 		gcActivityMax = stackMax(gcActivity);
% % 	else
% % 		gcActivityMax = (9*gcActivityMax  + stackMax(gcActivity))/10;
% % 	end
% % 	Fcpu = gather(Fsmooth);
% % 	for k=1:size(gcActivity,3)
% % 		gcChannel = pos(single(gcActivity(:,:,k)).*(1-controlMask)./single(gcActivityMax) - .7);
% % 		tdChannel = single(gcActivity(:,:,k)).*controlMask./single(gcActivityMax);
% % 		gcim.AlphaData = gather(gcChannel);
% % 		tdim.AlphaData = gather(tdChannel);
% % 		meanIm.CData = Fcpu(:,:,k).^2 ./ (1 + Fcpu(:,:,k).^2 ./ (2*single(Fvar)));
% % 		drawnow
% % 		im = getframe(h.ax);
% % 		writeVideo(writerObj, im.cdata)
% % 				
% % 	end
% 	
% % end
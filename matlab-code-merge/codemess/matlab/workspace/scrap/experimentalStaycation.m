warning('experimentalStaycation.m being called from scrap directory: Z:\Files\MATLAB\toolbox\ignition\scrap')
%%
if ~exist('TL','var')
	TL = scicadelic.TiffStackLoader;
	TL.FramesPerStep = 16;
	setup(TL)
end

MF = scicadelic.HybridMedianFilter;

CE = scicadelic.LocalContrastEnhancer;
% CE.UseInteractive = true;

MC = scicadelic.RigidMotionCorrector;
MC.CorrectionInfoOutputPort = false;
MC.AlwaysAlignToMovingAverage = false;
% MC.UseSmallSubWindow = true;
% MC.AdjunctFrameInputPort = true;
% MC.AdjunctFrameOutputPort = true;

% SC = scicadelic.StatisticCollector;
SC = scicadelic.StatisticCollector;
% SC.DifferentialMomentOutputPort = true;


PGC = scicadelic.PixelGroupController;
obj = PGC;


%%
% RP = scicadelic.RegionPropagator;
% CSS = scicadelic.CellSizedSurroundSampler;
% BTF = scicadelic.BinPixelTemporalFilter;
% BSF = scicadelic.BinPixelSpatialFilter;
% PH.UseInteractive = true;


%% DATA SAMPLE & TUNING
% [sdata, sinfo] = getDataSample(TL);
% release(TL);

%%
% tune(CE, sdata)

%%
% sdata = getProcessedTuningData(CE);
% tune(CD, sdata)

%%
% bw = getProcessedTuningData(CD);


%%
% imLoader = TL;
% imProcessor = {CE, MC, CD};

%% PREALLOCATE
% N = TL.NFrames;
N = TL.NumFrames;
numRows = TL.FrameSize(1);
numCols = TL.FrameSize(2);
numPixels = numRows*numCols;
numFrames = TL.FramesPerStep;
numSteps = ceil(N/numFrames);
dataType = TL.OutputDataType;

%%
groupSignal = cell(numSteps,1);



%% INITIALIZE PROCESSING LOOP
tTotal = tic;
reset(TL)
idx = 0;
m = 0;

%% RUN PROCESSING LOOP
while idx(end) < N
	% LOOP ==================
	% LOOP ==============
	% LOOP ==========
	
	
	
	% LOOP ==========
	% LOOP ==============
	% LOOP =================
	t = tic;
	m=m+1;
	
	% LOAD
	[F, idx] = TL.step();
	fRaw = F;
	fprintf('IDX: %d-%d ===\t',idx(1),idx(end));
	loadTime = toc(t);
	fprintf('Load: %3.3gms\t',1000*loadTime/numFrames); t=tic;
	
	
	% HYBRID MEDIAN FILTER ON GPU
	F = step(MF, F);
	
	% CONTRAST ENHANCEMENT
	F = step(CE, F);
		
	% MOTION CORRECTION	
	F = step( MC, F);
	
	processTime = toc(t);
	fprintf('PreProc: %3.3gms\t',1000*processTime/numFrames);t=tic;
	
	
	% NEW: PIXEL-GROUP CONTROLLER
	[labelGroupSignal, pixelLabel] = step(PGC,F);
	processTime = toc(t);
	fprintf('Label: %3.3gms\t',1000*processTime/numFrames);t=tic;
	
	
	% STATISTIC COLLECTION
	step(SC, F)
	processTime = toc(t);
	fprintf('Stats: %3.3gms\t',1000*processTime/numFrames);t=tic;
	
	
	% LABEL ASSIGMENTS <- L	
	groupSignal{m} = oncpu(labelGroupSignal);	
	try
		groupID = oncpu(sparse(double(reshape(pixelLabel, numRows, []))));
	catch % for versions earlier than R2015a
		groupID = sparse(oncpu(double(reshape(pixelLabel, numRows, []))));
	end
		
	% SHOW LABEL-MATRIX
	if exist('h','var') && isfield(h,'imRandomColor') && isvalid(h.imRandomColor(1))
		if rand>1/20
			h.imRandomColor.CData = full(groupID(:,1:numCols));
			h.fig.UserData = PGC.PixelLayer;
		else
			h = imrcOverlay(groupID(:, 1:numCols), PGC.PixelLayer);
		end
	else
		h = imrcOverlay(groupID(:, 1:numCols), PGC.PixelLayer);
	end
	drawnow
	
	
	% SAVE ALL INFO IN WORKSPACE
	if m==1
		motionInfo = repmat(MC.CorrectionInfo, numSteps,1);
		% 		statChunk = repmat(getStatistics(SC), numSteps,1);
	else
		motionInfo(m) = MC.CorrectionInfo;
		% 		statChunk(m) = getStatistics(SC); % 30ms
	end
	processTime = toc(t);
	fprintf('GPU2CPU: %3.3gms\n',1000*processTime/numFrames);
	
	
	% LOOP ==================
	% LOOP ==============
	% LOOP ==========
	
	
	
	% LOOP ==========
	% LOOP ==============
	% LOOP =================
end

%% REPORT TOTAL TIME
totalProcessTime = toc(tTotal);
fprintf([...
	'===========================\n\n',...
	'TOTAL-TIME:\n\t %3.3g minutes',...
	'\n\t%3.3g ms/frame\n',...
	'===========================\n\n'],...
	totalProcessTime/60, 1000*totalProcessTime/N);


%% GATHER CHUNKED INFO
mot = unifyStructArray(motionInfo);

%% RELEASE PROCESSING SYSTEMS
release(TL)
release(MC)
release(SC)
release(CE)
release(PGC)
%

%% GATHER & PLOT LABELED-ENCODED TRACES

uLockedLabel = unique(nonzeros(PGC.LockedPixelLabel));
labelRow = bitand( uLockedLabel , uint32(65535));
labelCol = bitand( bitshift(uLockedLabel, -16), uint32(65535));
labelIdx = labelRow + numRows*(labelCol-1);

chunkNumFrames = cellfun(@numel, groupSignal)/numPixels;
totalNumFrames = sum(chunkNumFrames(:));
totalNumRois = numel(labelIdx);
sparseTempMemRequiredEstimate = (nnz(groupSignal{1})/chunkNumFrames(1) * totalNumFrames * 8 * 2) / (2^30);
fullTempMemRequiredEstimate = (totalNumRois * totalNumFrames * 8 * 2 * 2) / (2^30);
tempMemRequiredEstimate = sparseTempMemRequiredEstimate + fullTempMemRequiredEstimate;
if (tempMemRequiredEstimate < GBavailable/2)
	labeledGroupData = cat(2, groupSignal{:});
	
	lgdMixTC = full(labeledGroupData(labelIdx,:)'); % lfsMixTC = full(lfsData(lfsidx,:)'); % transpose can screw things up
	lgdMix = reshape(typecast(lgdMixTC(:), 'uint16'), 4, size(lgdMixTC,1), [] );
	Fsize = squeeze(lgdMix(1,:,:));
	Fmean = squeeze(lgdMix(2,:,:));
	Fmax = squeeze(lgdMix(3,:,:));
	Fmin = squeeze(lgdMix(4,:,:));
else
	Fsize(totalNumFrames,totalNumRois) = uint16(0);
	Fmean(totalNumFrames,totalNumRois) = uint16(0);
	Fmax(totalNumFrames,totalNumRois) = uint16(0);
	Fmin(totalNumFrames,totalNumRois) = uint16(0);
	idx = 0;
	m = 0;
	while (idx(end) < totalNumFrames)
		m = m + 1;
		idx = idx(end) + (1:chunkNumFrames(m));
		labeledGroupData = groupSignal{m};
		lgdMixTC = full(labeledGroupData(labelIdx,:)');
		lgdMix = reshape(typecast(lgdMixTC(:), 'uint16'), 4, size(lgdMixTC,1), [] );
		Fsize(idx,:) = squeeze(lgdMix(1,:,:));
		Fmean(idx,:) = squeeze(lgdMix(2,:,:));
		Fmax(idx,:) = squeeze(lgdMix(3,:,:));
		Fmin(idx,:) = squeeze(lgdMix(4,:,:));
	end
end

if exist('h','var') && isfield(h,'fig') && isvalid(h.fig)
	close(h.fig)
end
plotMaxMinMean(Fmax, Fmin, Fmean);


% ccdr













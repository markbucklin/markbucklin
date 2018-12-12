%%
if ~exist('TL','var')
	TL = scicadelic.TiffStackLoader;
	TL.FramesPerStep = 16;
	setup(TL)
end
CE = scicadelic.LocalContrastEnhancer;
% CE.UseInteractive = true;

MC = scicadelic.RigidMotionCorrector;
MC.CorrectionInfoOutputPort = false;
MC.AlwaysAlignToMovingAverage = false;
% MC.AdjunctFrameInputPort = true;
% MC.AdjunctFrameOutputPort = true;

% CSS = scicadelic.CellSizedSurroundSampler;
% BTF = scicadelic.BinPixelTemporalFilter;
% BSF = scicadelic.BinPixelSpatialFilter;
% PH.UseInteractive = true;

SC = scicadelic.StatisticCollector;
% RP = scicadelic.RegionPropagator;


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
% fsdData = zeros([TL.FrameSize N], 'single');
% fData = zeros([TL.FrameSize N], dataType);
% bwData = zeros([TL.FrameSize N], 'uint16');
% cData = zeros([TL.FrameSize N], 'int8');

% lfsData = spalloc(numPixels, N, 4096*N);




lfsDataCell = cell(numSteps,1);
% lCell = cell(numSteps,1);
LsizeSum = zeros(numRows*numCols,1);
% lSparseCell = cell(numSteps,1);
pData = zeros([TL.FrameSize numSteps], 'single');

%% INITIALIZE PROCESSING LOOP
tTotal = tic;
reset(TL)
idx = 0;
m = 0;
L = [];
P = [];
lockedLabel = [];
Lcnt = [];

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
	F = runHybridMedianFilterGpuKernel(F);
	
	
	% CONTRAST ENHANCEMENT
	F = step(CE, F);
	
	
	% MOTION CORRECTION
	try
		F = step( MC, F);
	catch me
		% 		showError(me)
		pause(.1)
		F = step(MC, F);
	end
	% 	[F, fRaw] = step( MC, F, fRaw);	
	processTime = toc(t);
	fprintf('PreProc: %3.3gms\t',1000*processTime/numFrames);t=tic;
	
	
	% NEW: NEIGHBORHOODSAMPLING
	if isempty(L)
		[L, P, LFS, Lsize, lockedLabel, Lcnt, Lsteady] = labelPixels(F);
	else
		if isempty(P)
			[L, P, LFS, Lsize, lockedLabel, Lcnt, Lsteady] = labelPixels(F,L);
		else
			if isempty(lockedLabel)
				[L, P, LFS, Lsize, lockedLabel, Lcnt, Lsteady] = labelPixels(F,L,P);
			else
				if isempty(Lcnt)
					[L, P, LFS, Lsize, lockedLabel, Lcnt, Lsteady] = labelPixels(F,L,P, lockedLabel);
				else
					[L, P, LFS, Lsize, lockedLabel, Lcnt, Lsteady] = labelPixels(F,L,P, lockedLabel, Lcnt);
				end
			end
		end
	end
	processTime = toc(t);
	fprintf('Label: %3.3gms\t',1000*processTime/numFrames);t=tic;
	
	
	% STATISTIC COLLECTION
	step(SC, F)
	processTime = toc(t);
	fprintf('Stats: %3.3gms\t',1000*processTime/numFrames);t=tic;
	
	
	% SEGMENTATION -> make composite object?
	% 	bw = step(CSS, data);	% 1.8ms (peak at 32)
	% 	bw = step(BTF, bw); % .09ms (peak past 128)
	% 	bw = step(BSF, bw); % 4.22ms (peak around 2)
	% 	bwCpu = oncpu(bw);
	
	
	% LABELED REGION GENERATION/PROPAGATION
	% 	step(RP, rawData, bwCpu, oncpu(idx));
	
	
	% SAVE FULL VIDEO IN WORKSPACE
	% 	fData(:,:,idx) = oncpu(F);
	% 	cData(:,:,idx) = oncpu(int8(C));
	% 	pData(:,:,idx) = oncpu(int16(P));
	% 	lfsData(:,idx) = oncpu(LFS);
	% 	bwData(:,:,idx) = bwCpu;
	
	
	% LABEL ASSIGMENTS <- L
% 	lCell{m} = oncpu(nonzeros(L));		
	lfsDataCell{m} = oncpu(LFS);
	pData(:,:,m) = oncpu(P);
	lsc = oncpu(sparse(double(reshape(L, numRows, []))));
	LsizeSum = LsizeSum + double(sum( reshape(Lsize, numPixels, []),2));
	% lSparseCell{m} = lsc;	
	
	
	% SHOW LABEL-MATRIX
	if exist('h','var') && isfield(h,'im') && isvalid(h.im(1))
		if rand>1/20
			h.im.CData = full(lsc(:,1:numCols));
		else
			imrc(lsc(:, 1:numCols))
		end
	else
		imrc(lsc(:, 1:numCols))
	end
	drawnow
	
	
	% SAVE ALL INFO IN WORKSPACE
	if m==1
		motionInfo = repmat(MC.CorrectionInfo, numSteps,1);
		statChunk = repmat(getStatistics(SC), numSteps,1);
	else
		motionInfo(m) = MC.CorrectionInfo;
		statChunk(m) = getStatistics(SC); % 30ms
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
try
% christ, pain in the butt. TODO: fix. Deals with only part of structure array at a time to avoid going over memory lim
if GBavailable > GB(statChunk)*2
	stat = unifyStructArray(statChunk, 3); % (original line)
else
	nSplit = ceil(2*GB(statChunk)/GBavailable);
	splitIdx = round(linspace(1,numel(statChunk)+1,nSplit+1));
	for k=1:nSplit
		statChunkCell = statChunk(splitIdx(k):(splitIdx(k+1)-1));
	end
	statChunk = [];
	for k=1:nSplit
		stat(k) = unifyStructArray(statChunkCell{1}, 3);
		if k==nSplit
			statChunkCell = [];
		else
			statChunkCell = statChunkCell(2:end);
		end
	end
end
statChunkCell = [];

statChunk = [];
catch me
	keyboard
end

%% RELEASE PROCESSING SYSTEMS
release(TL)
release(MC)
release(SC)
release(CE)
%

%% GATHER & PLOT LABELED-ENCODED TRACES
lfsData = cat(2, lfsDataCell{:});

uLockedLabel = unique(lockedLabel);
lcRow = bitand( uLockedLabel , uint32(65535));
lcCol = bitand( bitshift(uLockedLabel, -16), uint32(65535));
lfsIdx = lcRow + numRows*(lcCol-1);

% minAvgSize = 9;
% lfsidx = find(LsizeSum>N*minAvgSize); % NEW


lfsMixTC = full(lfsData(lfsIdx,:)'); % lfsMixTC = full(lfsData(lfsidx,:)'); % transpose can screw things up
lfsMix = reshape(typecast(lfsMixTC(:), 'uint16'), 4, size(lfsMixTC,1), [] );
Fsize = squeeze(lfsMix(1,:,:));
Fmean = squeeze(lfsMix(2,:,:));
Fmax = squeeze(lfsMix(3,:,:));
Fmin = squeeze(lfsMix(4,:,:));

if exist('h','var') && isfield(h,'fig') && isvalid(h.fig)
	close(h.fig)
end
plotMaxMinMean(Fmax, Fmin, Fmean);


% ccdr













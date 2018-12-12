
%%

TL = ignition.stream.io.TiffFileInput;
TL.FrameDataOutputPort = true;
TL.FrameTimeOutputPort = true;
TL.FrameIdxOutputPort = true;
TL.VideoSegmentOutputPort = false;

% [frameData, frameTime, frameIdx] = step(TL);
% F = single(gpuArray(frameData));

%%


dev = gpuDevice;
reset(dev);
parallel.gpu.rng(7301986,'Philox4x32-10');



%% PROCESSING SYSTEMS
proc.mf = ignition.stream.HybridMedianFilter;
proc.ce = ignition.stream.LocalContrastEnhancer;
proc.ce.LpFilterSigma = 7;
proc.ce.UseInteractive = true;
proc.mc = ignition.stream.MotionCorrector;
proc.tgsc = ignition.stream.TemporalGradientStatisticCollector;
proc.tgsc.DifferentialMomentOutputPort = true;
proc.tgsc.GradientRestriction = 'Positive Only'; %'Absolute Value';
proc.tf = ignition.stream.TemporalFilter;
proc.sc = ignition.stream.StatisticCollector('DifferentialMomentOutputPort',true);
% proc.tgtf = ignition.stream.TemporalFilter('MinTimeConstantNumFrames',4);


%% OUTPUT EXTRACTORS (IMAGE NORMALIZERS)
% INr = ignition.stream.ImageNormalizer('NormalizationType','Geman-McClure');
gmcRstat = [];
INg = ignition.stream.ImageNormalizer('NormalizationType','ExpNormComplement');
% INb = ignition.stream.ImageNormalizer('NormalizationType','Geman-McClure');
gmcBstat = [];
MF = proc.mf;


%% PROCEDURE ORDER
feedThroughSystem = {...
	proc.mf
	proc.ce
	proc.mc
	proc.tf
% 	proc.tgtf
	};
otherSystem = {...
	proc.tgsc
	proc.sc
% 	INr
	INg
% 	INb
	};
allSystems = cat(1,{TL},feedThroughSystem,otherSystem);

%% PREALLOCATE VARIABLES & DATA-OUTPUT ARRAYS

% SIZE/DIMENSION
numRows = TL.FrameSize(1);
numCols = TL.FrameSize(2);
N = TL.NumFrames;
% numFrames = TL.FramesPerStep;
numFrames = TL.NumFramesPerStep;
numSteps = ceil(N/numFrames);


% LARGE ARRAYS FOR DATA OUTPUT
% Frgb(numRows,numCols,3,N) = uint8(0);
% Fr(numRows,numCols,N) = single(0);
% Fb(numRows,numCols,N) = single(0);
nidx = 0;
% Fcpu(numRows,numCols,N) = uint16(0);
Frgb_cell = cell(numSteps,1);



%% PMI
% displacements = [1 2]; %2.^(0:5); %[1 2 3 5 7 10];%pow2(0:4); % maxdiameter=33pixels
% Qmin = .1;
% numDisplacements = numel(displacements);
idx0 = 512;
% numPmiChunks = floor((N - idx0)/numFrames);
% pmi = zeros(numRows,numCols,8*numDisplacements, numPmiChunks, 'int8');
% Iycpu = zeros(numRows,numCols,1, numPmiChunks, 'int8');
% Ixcpu = zeros(numRows,numCols,1, numPmiChunks, 'int8');
% Isymcpu = zeros(numRows,numCols,1, numPmiChunks, 'single');
% S0cpu = zeros(numRows,numCols,3,numPmiChunks, 'uint8');
% newmax = zeros(numRows,numCols,numPmiChunks, 'single');
% BW = false(numRows,numCols,N-idx0);
% BWL = false(numRows,numCols,N-idx0);
% P = [];
% Qmin = [];
% P0 = [];
bw = [];
bwl = [];
dm=0;
didx = 0;

obj = ignition.stream.PixelLabel;

%% INITIALIZE COUNTERS
idx = 0;
m = 0;
% stopIdx = N;
stopIdx = 128;


%% RUN CHUNKS IN LOOP
while ~isempty(idx) && (idx(end) < stopIdx)
	%
	
	m=m+1;
	
	% ------------------------------------
	% LOAD
	% ------------------------------------
	bt.loadtic = tic;
	[F, idx] = TL.step();
	bt.loadtoc = toc(bt.loadtic);
	
	
	% ------------------------------------
	% PROCESS
	% ------------------------------------
	bt.proctic = tic;
	
	% HYBRID MEDIAN FILTER ON GPU
	F = step(proc.mf, F);
	
	% CONTRAST ENHANCEMENT
	F = step(proc.ce, F);
	
	% MOTION CORRECTION
	[F,motionInfo(m)] = step( proc.mc, F);
	
	% TEMPORAL SMOOTHING (ADAPTIVE)
	F = step(proc.tf, F);
	
	% TEMPORAL GRADIENT STATISTSTICS
	gdstat = step(proc.tgsc, F);
	
	% STATISTIC COLLECTION
	dstat = step(proc.sc, F);
	
	% BENCHMARK-TIME
	bt.proctoc = toc(bt.proctic);
	
	
	
	% ------------------------------------
	% TRANSFER/EXTRACT/SAVE/OUTPUT DATA
	% ------------------------------------
	bt.savetic = tic;
	
	% RGB EXTRACTION
	numFrames = numel(idx);
	
	% RAW DATA OUTPUT (FLUORESCENCE-INTENSITY & MOTION)
% 	Fcpu(:,:,idx) = gather(F);
	
	% RGB DATA OUTPUT (DIFFERENTIAL MOMENTS)
	fR = dstat.M4;
	fR = step(MF, fR);
	[fR, gmcRstat] = gemanMcClureNormalizationRunGpuKernel(fR, gmcRstat);
	fG = F;
	fG = step(INg, fG);
	fB = gdstat.M3;
	fB = step(MF, fB);
	[fB, gmcBstat] = gemanMcClureNormalizationRunGpuKernel(fB, gmcBstat); % if < 512 use fB/max(fB)??
	
	fA = min( 1, fR + fB); % fA = min( 1, fR + max(fB, step(proc.tgtf,fB)) );
	% 	fA = max( fA, step(proc.tgtf, fA));
	
	% 	Frgb(:,:,:,idx) = gather( cat(3, ...
	Frgb_cell{m} = gather( cat(3, ...
		uint8(reshape(fR.*255, numRows, numCols, 1, numFrames)) ,...
		uint8(reshape(fG.*255, numRows, numCols, 1, numFrames)) ,...
		uint8(reshape(fB.*255, numRows, numCols, 1, numFrames))) );
	
	% BENCHMARK-TIME
	bt.savetoc = toc(bt.savetic);
	
	% BW
	bt.updatetic = tic;
	% 	if idx(1) > idx0
	% 		dm = dm + 1;
	% 		didx = didx(end) + (1:numel(idx));
	% 		Q = fR;
	% 		% 		[PMI, Hab, P] = pointwiseMutualInformationRunGpuKernel(Q, P, Qmin, displacements);
	% 		[PMI, Hab, P] = pointwiseMutualInformationRunGpuKernel(Q, [], Qmin, displacements);
	%
	% 		pmiMin = min(max(0,PMI),[],3);
	% 		bw = pmiMin > .05;
	
	Q = fR;
	update(obj, Q);
	oCxy{m} = gather(obj.RegionCentroid);
	oArea{m} = gather(obj.RegionArea);
	bt.updatetoc = toc(bt.updatetic);
	
	% 	end
	% 	oldmax = proc.sc.Max;
	
	
	% REPORT
	tms = 1000.*[bt.loadtoc, bt.proctoc, bt.savetoc, bt.updatetoc]./numFrames;
	fprintf('IDX: %d-%d ~~~~~~~~~~~~~\n\t',idx(1),idx(end));
	fprintf('Load: %3.3gms\tProcess: %3.3gms\tSave: %3.3gms\tUpdate: %3.3gms\t\n',tms(1),tms(2),tms(3),tms(4));
	
	imrc(obj.PrimaryRegionIdxMap)
	disp(obj.NumRegisteredRegions)
	drawnow
	%
	
end


% imsc(obj.LabeledRegionPixelStatistics.MeanArea)
%  imsc(obj.LabeledRegionPixelStatistics.EnSeedability - stat.EnSeedability)
%  stat = obj.LabeledRegionPixelStatistics;

%%
% mot = unifyStructArray(motionInfo);


%%
% 
% cellfun(@release, allSystems)
% 
% if false
% 	cellfun(@release, allSystems)
% 	cellfun(@delete, feedThroughSystem)
% 	cellfun(@delete, otherSystem)
% 	dev = gpuDevice;
% 	dev.reset;
% end




%%

% Frgb = cat(4, Frgb_cell{:});
% Fr = Frgb(:,:,1,:);
% Fb = Frgb(:,:,3,:);
% Fg = Frgb(:,:,2,:);
% T = gather(obj.RegisteredLabelIdxMap);
% Trgbcmap = label2rgb(T,'lines','k');
% Trgb = bsxfun(@plus, uint8(single(256) .* ...
% 	bsxfun(@times, 1/255.*single(Trgbcmap), 1/255 .* (.75*single(Fr)+single(Fb)))) , Fg);



% imrgbplay(cat(3, uint8(abs(Iycpu)*2), uint8(255*Isymcpu) , uint8(abs(Ixcpu)*2)))
% imscplay(sqrt(single(Iycpu).^2+single(Ixcpu).^2))
% imscplay(Isymcpu - single((1/128.*sqrt(single(Iycpu).^2+single(Ixcpu).^2))))

%%
% ringStep = 0;
% pmirgb = uint8( single(pmi(:,:,ringStep+[1,6,5],:)) - single(pmi(:,:,ringStep+[8,3,4],:)) + 128).*(1/numDisplacements);
% for kRing = 2:numDisplacements
% 	ringStep = (kRing-1)*8;
% 	pmirgb = pmirgb + uint8( single(pmi(:,:,ringStep+[1,6,5],:)) - single(pmi(:,:,ringStep+[8,3,4],:)) + 128).*(1/numDisplacements);
% 
% end
% imrgbplay(pmirgb,.1)










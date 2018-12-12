% function varargout = sparkyagain(TL)
%
% if nargin < 1
% 	TL = [];
% end


%% LOADING SYSTEM
if ~exist('TL','var') || isempty(TL)
	TL = scicadelic.TiffStackLoader;
	TL.FramesPerStep = 16;
	% 	Fsample = getDataSample(TL); %TODO
	setup(TL)	
else
	if exist('allSystems','var')
		try
			cellfun(@release, allSystems)
			cellfun(@delete, feedThroughSystem)
			cellfun(@delete, otherSystem)
		catch me
			getReport(me)
		end
	end
	reset(TL)
end

%%
dev = gpuDevice;
reset(dev);
parallel.gpu.rng(7301986,'Philox4x32-10');

%% PROCESSING SYSTEMS
proc.mf = scicadelic.HybridMedianFilter;
proc.ce = scicadelic.LocalContrastEnhancer;
proc.mc = scicadelic.MotionCorrector;
proc.tgsc = scicadelic.TemporalGradientStatisticCollector;
proc.tgsc.DifferentialMomentOutputPort = true;
proc.tgsc.GradientRestriction = 'Absolute Value';
proc.tf = scicadelic.TemporalFilter; % scicadelic.AdaptiveTemporalFilter;
proc.sc = scicadelic.StatisticCollector('DifferentialMomentOutputPort',true);

%% OUTPUT EXTRACTORS (IMAGE NORMALIZERS)
INr = scicadelic.ImageNormalizer('NormalizationType','Geman-McClure');
gmcRstat = [];
INg = scicadelic.ImageNormalizer('NormalizationType','ExpNormComplement');
INb = scicadelic.ImageNormalizer('NormalizationType','Geman-McClure');
gmcBstat = [];
MF = proc.mf;

%% PROCEDURE ORDER
feedThroughSystem = {...
	proc.mf
	proc.ce
	proc.mc
	proc.tf
	};
otherSystem = {...
	proc.tgsc
	proc.sc
	INr
	INg
	INb
	};
allSystems = cat(1,{TL},feedThroughSystem,otherSystem);

%% PREALLOCATE VARIABLES & DATA-OUTPUT ARRAYS

% SIZE/DIMENSION
numRows = TL.FrameSize(1);
numCols = TL.FrameSize(2);
N = TL.NumFrames;
numFrames = TL.FramesPerStep;
numSteps = ceil(N/numFrames);


% LARGE ARRAYS FOR DATA OUTPUT
Frgb(numRows,numCols,3,N) = uint8(0);
Fr(numRows,numCols,N) = single(0);
Fb(numRows,numCols,N) = single(0);
nidx = 0;
Fcpu(numRows,numCols,N) = uint16(0);


%% *********   TEMPORARY **********
% nlstat = [];




% *********   TEMPORARY **********

%% INITIALIZE COUNTERS
idx = 0;
m = 0;

%% RUN CHUNKS IN LOOP
while ~isempty(idx) && (idx(end) < N)
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
	F = step( proc.mc, F);
	motionInfo(m) = gather(proc.mc.CorrectionInfo);
	
	% TEMPORAL SMOOTHING (ADAPTIVE)
	F = step(proc.tf, F);
	
	% TEMPORAL GRADIENT STATISTSTICS
	gdstat = step(proc.tgsc, F);
	
	% STATISTIC COLLECTION
	dstat = step(proc.sc, F);
	
	% *********   TEMPORARY **********
	% 	if ~isempty(nlstat)
	% 		nlstat = nonLocalStatisticUpdateRunGpuKernel(F,nlstat);
	% 	else
	% 		nlstat = nonLocalStatisticUpdateRunGpuKernel(F);
	% 	end
	% *********   TEMPORARY **********
	
	
	% BENCHMARK-TIME
	bt.proctoc = toc(bt.proctic);
	
	% ------------------------------------
	% TRANSFER/EXTRACT/SAVE/OUTPUT DATA
	% ------------------------------------
	bt.savetic = tic;
	
	% RGB EXTRACTION
	numFrames = numel(idx);
	
	% RAW DATA OUTPUT (FLUORESCENCE-INTENSITY & MOTION)
	Fcpu(:,:,idx) = gather(F);
	
	% RGB DATA OUTPUT (DIFFERENTIAL MOMENTS)
	% 	dstat_cpu(m) = oncpu(dstat);
	% 	gdstat_cpu(m) = oncpu(gdstat);
	fR = dstat.M4;
	fR = step(MF, fR);
	% 	fR = step(INr, fR);
	[fR, gmcRstat] = gemanMcClureNormalizationRunGpuKernel(fR, gmcRstat);		
	Fr(:,:,idx) = gather(fR);	
	fG = F;
	fG = step(INg, fG);
	fB = gdstat.M3;
	fB = step(MF, fB);
	% 	fB = step(INb, fB);
	[fB, gmcBstat] = gemanMcClureNormalizationRunGpuKernel(fB, gmcBstat);	
	Fb(:,:,idx) = gather(fB);
	
	Frgb(:,:,:,idx) = gather( cat(3, ...
		uint8(reshape(fR.*255, numRows, numCols, 1, numFrames)) ,...
		uint8(reshape(fG.*255, numRows, numCols, 1, numFrames)) ,...
		uint8(reshape(fB.*255, numRows, numCols, 1, numFrames))) );
	
	
	% PMI
	if idx(1) >512
		
		
	end
	
	
	% BENCHMARK-TIME
	bt.savetoc = toc(bt.savetic);
	
	% REPORT
	tms = 1000.*[bt.loadtoc, bt.proctoc, bt.savetoc]./numFrames;
	fprintf('IDX: %d-%d ~~~~~~~~~~~~~\n\t',idx(1),idx(end));
	fprintf('Load: %3.3gms\tProcess: %3.3gms\t''Save: %3.3gms\t\n',tms(1),tms(2),tms(3));
	
	
end
mot = unifyStructArray(motionInfo);


%%

cellfun(@release, allSystems)

if false
	cellfun(@release, allSystems)
	cellfun(@delete, feedThroughSystem)
	cellfun(@delete, otherSystem)
	dev = gpuDevice;
	dev.reset;
end





minArea = 20;



%% LOADING SYSTEM
if ~exist('TL','var') || isempty(TL)
	TL = scicadelic.TiffStackLoader;
	TL.FramesPerStep = 8;
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
gmcRstat = [];
INg = scicadelic.ImageNormalizer('NormalizationType','ExpNormComplement');
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
	INg
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
% Fr(numRows,numCols,N) = single(0);
% Fb(numRows,numCols,N) = single(0);
nidx = 0;
Fcpu(numRows,numCols,N) = uint16(0);




%% BW - ROI
idx0 = 512;
numRoiChunks = floor((N - idx0)/numFrames);
roiChunk = cell(numRoiChunks,1);
dm=0;
didx = idx0;
ROI = [];


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
	
    % ------------------------------------
	% RGB DATA OUTPUT (DIFFERENTIAL MOMENTS)	
    % ------------------------------------
    
    % DIFFERENTIAL KURTOSIS OF IMAGE INTENSITY (RED)
	fR = dstat.M4;
	fR = step(MF, fR);        
	[fR, gmcRstat] = gemanMcClureNormalizationRunGpuKernel(fR, gmcRstat);		
	
    % THRESHOLD 
    if idx(1) > idx0
        dm = dm+1;
        bw = fR > .05;
        bw = reshape( bwmorph( bwmorph( reshape(bw, numRows,[],1), 'majority'), 'fill'), numRows,numCols,[]);
        cc = bwconncomp(gather(bw),8);
        ccArea = cellfun(@numel,cc.PixelIdxList);        
        bwSmallIdx = cc.PixelIdxList(ccArea < minArea);
        bw(cat(1,bwSmallIdx{:})) = false;
        roi = RegionOfInterest(bw);
        roiChunk{dm} = roi;
        %         if ~isempty(ROI)
        %             ROI = reduceSuperRegions(cat(1,ROI(:),roi));
        %         else
        %             ROI = roi;
        %         end
    end
    
    % COMPLEMENT INTENSITY (GREEN)
	fG = F;
	fG = step(INg, fG);
    
    % DIFFERENTIAL SKEWNESS OF IMAGE INTENSITY TEMPORAL DERIVATIVE (BLUE)
	fB = gdstat.M3;
	fB = step(MF, fB);

	[fB, gmcBstat] = gemanMcClureNormalizationRunGpuKernel(fB, gmcBstat);	

	
	Frgb(:,:,:,idx) = gather( cat(3, ...
		uint8(reshape(fR.*255, numRows, numCols, 1, numFrames)) ,...
		uint8(reshape(fG.*255, numRows, numCols, 1, numFrames)) ,...
		uint8(reshape(fB.*255, numRows, numCols, 1, numFrames))) );
	
	% BENCHMARK-TIME
	bt.savetoc = toc(bt.savetic);
	
	% REPORT
	tms = 1000.*[bt.loadtoc, bt.proctoc, bt.savetoc]./numFrames;
	fprintf('IDX: %d-%d ~~~~~~~~~~~~~\n\t',idx(1),idx(end));
	fprintf('Load: %3.3gms\tProcess: %3.3gms\t''Save: %3.3gms\t\n',tms(1),tms(2),tms(3));
	
	
end
mot = unifyStructArray(motionInfo);


singleFrameRois = cat(1,roiChunk{:});
ROI = reduceRegions(singleFrameRois);
ROI = reduceSuperRegions(ROI);

X = makeTraceFromVid(ROI, Fcpu);

%%

cellfun(@release, allSystems)

if false
	cellfun(@release, allSystems)
	cellfun(@delete, feedThroughSystem)
	cellfun(@delete, otherSystem)
	dev = gpuDevice;
	dev.reset;
end


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


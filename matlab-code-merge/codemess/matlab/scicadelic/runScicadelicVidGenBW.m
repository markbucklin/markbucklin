function runScicadelicVidGenBW(TL)
% function scicadelicPathCleaner = runScicadelicVidGen(TL)

try
%scicadelicPathCleaner = addScicadelicToPath();

%%

% INITIALIZE GPU
dev = gpuDevice;
reset(dev);
parallel.gpu.rng(7301986,'Philox4x32-10');

% INITIALIZE THREAD POOL
pool = gcp;

if (nargin<1)
	TL = scicadelic.TiffStackLoader;
	TL.FramesPerStep = 32;
	TL.FrameInfoOutputPort = true;
	setup(TL)
else
	reset(TL)
end
numVideoFrames = TL.NumFrames;

try
    fprintf('Processing files in %s\n', TL.FileDirectory)
    fprintf('\t%s\n', TL.FileName{:})
catch
end


%% RGB - MP4 OUTPUT


% FILE NAME
try
	videoFile = scicadelic.FileWrapper('FileName',TL.FileName, 'FileDirectory', TL.FileDirectory);
	defaultDataSetName = videoFile.DataSetName;
catch
	defaultDataSetName = TL.DataSetName;
end
if isempty(defaultDataSetName)
	defaultDataSetName = 'defaultdatasetname';
end
defaultExportPath = [TL.FileDirectory, 'export'];
if ~isdir(defaultExportPath)
	mkdir(defaultExportPath)
end
dateStamp = datestr(now,'(yyyymmmdd_HHMMPM)');
rgbFileName = [defaultExportPath,filesep, [defaultDataSetName,'_rgb'], dateStamp, '.mp4'];
grayFileName = [defaultExportPath,filesep, [defaultDataSetName,'_gray'], dateStamp, '.avi'];

% MP4 COMPRESSION & FRAMERATE SETTINGS
% fpsMultiplier = 2;
% Tduration = TL.LastFrameTime - TL.FirstFrameTime ;
% FPSmp4 = fpsMultiplier * TL.StackInfo.numFrames/ Tduration;
FPS = 80;
FPSdescription = '2X (Approximate)';

% RGB COMPRESSED MP4
rgbProfile = 'MPEG-4';
rgbWriterObj = VideoWriter(rgbFileName,rgbProfile);
rgbWriterObj.FrameRate = FPS;
rgbWriterObj.Quality = 98; %new (was 95)
addlistener(rgbWriterObj, 'ObjectBeingDestroyed', @(src,evnt)close(src) );
open(rgbWriterObj)

% GRAYSCALE UNCOMPRESSED AVI
grayProfile = 'Uncompressed AVI';
grayWriterObj = VideoWriter(grayFileName,grayProfile);
grayWriterObj.FrameRate = FPS;
%grayWriterObj.Quality = 98; %new (was 95)
addlistener(grayWriterObj, 'ObjectBeingDestroyed', @(src,evnt)close(src) );
open(grayWriterObj)

% (remember to)
% writeVideo(writerObj, F)


%% PROCESSING SYSTEMS
proc.mf = scicadelic.HybridMedianFilter;
proc.ce = scicadelic.LocalContrastEnhancer;
proc.ce.LpFilterSigma = 5;
proc.ce.UseInteractive = true;
proc.mc = scicadelic.MotionCorrector;
proc.tgsc = scicadelic.TemporalGradientStatisticCollector;
proc.tgsc.DifferentialMomentOutputPort = true;
proc.tgsc.GradientRestriction = 'Positive Only'; %'Absolute Value';
% proc.tgsc.GradientRestriction = 'Absolute Value';
proc.tf = scicadelic.TemporalFilter;
proc.tf.MinTimeConstantNumFrames = 4;% new
proc.sc = scicadelic.StatisticCollector('DifferentialMomentOutputPort',true);
% proc.tgtf = scicadelic.TemporalFilter('MinTimeConstantNumFrames',4);


%% OUTPUT EXTRACTORS (IMAGE NORMALIZERS)
% INr = scicadelic.ImageNormalizer('NormalizationType','Geman-McClure');
gmcRstat = [];
INg = scicadelic.ImageNormalizer('NormalizationType','ExpNormComplement');
% INb = scicadelic.ImageNormalizer('NormalizationType','Geman-McClure');
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
N = TL.numFrames;
% numFrames = TL.FramesPerStep;
numFrames = TL.FramesPerStep;

%% INITIALIZE COUNTERS
idx = 0;
m = 0;
stopIdx = N;
% stopIdx = 128;


%% RUN CHUNKS IN LOOP
s0 = [];
sa = [];
while ~isempty(idx) && (idx(end) < stopIdx)
	%
	try
		m=m+1;
		
		%% LOAD ------------------------------------
		bt.loadtic = tic;
		% 	[F, idx] = TL.step();
		
		if isDone(TL)
			break
		else
			% 			[frameData, frameIdx] = step(TL);
			% 			[frameData, frameTime, frameIdx] = step(TL);
			[frameData, frameInfo, frameIdx] = step(TL);
			frameTime = frameInfo.t;
		end
		
		F = single(squeeze(gpuArray(frameData)));
		idx = frameIdx;
		bt.loadtoc = toc(bt.loadtic);
		
		%% PROCESS ------------------------------------
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
		gdstat = step(proc.tgsc, F, frameTime);
		
		% STATISTIC COLLECTION
		dstat = step(proc.sc, F);
		
		% BENCHMARK-TIME
		bt.proctoc = toc(bt.proctic);
		
		
		
		
		%% TRANSFER/EXTRACT/SAVE/OUTPUT DATA 
		bt.savetic = tic;
		
		% RGB EXTRACTION
		numFrames = numel(idx);
		
		% RAW DATA OUTPUT (FLUORESCENCE-INTENSITY & MOTION)
		% 	Fcpu(:,:,idx) = gather(F);
		
        
        %% GRAY OUTPUT
        Fcpu = gather(F);
        for kg = 1:numFrames
            writeVideo(grayWriterObj, Fcpu(:,:,kg));
        end
        
		%% RGB DATA OUTPUT
		
		try
			% TRY OLD WAY (NO BACKGROUND)
			
			% RED
			fRed = dstat.M4;
			fRed = step(MF, fRed);			
			[fRed, gmcRstat] = gemanMcClureNormalizationRunGpuKernel(fRed, gmcRstat);			% 	fR = step(INr, fR);
			
			% GREEN
			fGreen = F;
			fGreen = step(INg, fGreen);
			
			% BLUE
			fBlue = gdstat.M3;
			fBlue = step(MF, fBlue);			
			[fBlue, gmcBstat] = gemanMcClureNormalizationRunGpuKernel(fBlue, gmcBstat); % 	fB = step(INb, fB);			
			
			% RGB - COMPOSITE
			fRGB = gather( cat(3, ...
				uint8(reshape(fRed.*255, numRows, numCols, 1, numFrames)) ,...
				uint8(reshape(fGreen.*255, numRows, numCols, 1, numFrames)) ,...
				uint8(reshape(fBlue.*255, numRows, numCols, 1, numFrames))) );
			
			% 			Frgb(:,:,:,idx) = gather( cat(3, ...
			% 				uint8(reshape(fRed.*255, numRows, numCols, 1, numFrames)) ,...
			% 				uint8(reshape(fGreen.*255, numRows, numCols, 1, numFrames)) ,...
			% 				uint8(reshape(fB.*255, numRows, numCols, 1, numFrames))) );
			
		catch me
			% RGB DATA OUTPUT (DIFFERENTIAL MOMENTS)
			fBlue = dstat.M4;
			fBlue = step(MF, fBlue);
			[fBlue, gmcRstat] = gemanMcClureNormalizationRunGpuKernel(fBlue, gmcRstat);
			fGreen = F;
			fGreen = step(INg, fGreen);
			fRed = gdstat.M3;
			fRed = step(MF, fRed);
			[fRed, gmcBstat] = gemanMcClureNormalizationRunGpuKernel(fRed, gmcBstat); % if < 512 use fB/max(fB)??
			
			
			a = .90;
			if isempty(s0)
				s0 = mean(min(F,[],1),2);
				sa = mean(range(F,1),2);
			else
				s0 = s0(1:numFrames);
				sa = sa(1:numFrames);
				s0new = mean(min(F,[],1),2);
				sanew = mean(range(F,1),2);
				ks=1;
				s0(ks) = a*s0(end) + (1-a)*s0new(ks);
				sa(ks) = a*sa(end) + (1-a)*sanew(ks);
				while (ks < numFrames)
					ks = ks + 1;
					s0(ks) = a*s0(ks-1) + (1-a)*s0new(ks);
					sa(ks) = a*sa(ks-1) + (1-a)*sanew(ks);
				end
			end
			
			fBase = bsxfun( @times, (1./sa) , bsxfun(@minus, F , s0));
			% 		fBase = fBase.*(0.3 + (0.3*fRed + 0.2*fGreen + 0.2*fBlue));% new
			
			nanPix = isnan(fRed(:));
			if any(nanPix), fRed(nanPix) = 0; end
			nanPix = isnan(fGreen(:));
			if any(nanPix), fGreen(nanPix) = 0; end
			nanPix = isnan(fBlue(:));
			if any(nanPix), fBlue(nanPix) = 0; end
			
			% fRed = fRed .* (0.5 .* (1 + fBase))
			% fBlue = fBlue .* (0.5 .* (1 + fBase))
			
			fBlue = max( fBlue-fRed, 0);%nextrun % or fBlue = fBlue .* (1-fRed);
			rbc = single(0.3);
			% 		fBase = (fBase .* ( 1 - bsxfun(@max, fRed, fBlue)));
			%NEXT% fGreen = fGreen .* 0.5*( 1 + fBase);
			
			fRGB = gather( bsxfun(@plus, ...
				uint8(reshape( fBase.*255.*rbc, numRows,numCols,1,numFrames)), ...
				cat(3, ...
				uint8(reshape( fRed.*255, numRows, numCols, 1, numFrames)) ,...
				uint8(reshape( fGreen.*255.*(1-rbc), numRows, numCols, 1, numFrames)) ,...
				uint8(reshape( fBlue.*255, numRows, numCols, 1, numFrames))) ));
		end
		
		
		% SEND RGB FRAMES TO MP4 VIDEO WRITER
		writeVideo(rgbWriterObj, fRGB)
		
		%% BENCHMARK-TIME
		bt.savetoc = toc(bt.savetic);
		
	catch me
		msg = getReport(me);
		disp(msg)
		break
	end
end


% BW
% 	Fbw_cell{m} = gather(F);
% 	bt.updatetic = tic;


% hw = waitbar(0,'mp4');
% for k=1:(m-1)
% 	fRGB = Frgb_cell{k};
% 	writeVideo(writerObj, fRGB);
% 	waitbar(k/m,hw);
% 	pause(.001),
% end







% 	if idx(1) > idx0
% 		dm = dm + 1;
% 		didx = didx(end) + (1:numel(idx));
% 		Q = fR;
% 		% 		[PMI, Hab, P] = pointwiseMutualInformationRunGpuKernel(Q, P, Qmin, displacements);
% 		[PMI, Hab, P] = pointwiseMutualInformationRunGpuKernel(Q, [], Qmin, displacements);
%
% 		pmiMin = min(max(0,PMI),[],3);
% 		bw = pmiMin > .05;

% 	Q = fR;
% 	update(obj, Q);
% 	oCxy{m} = gather(obj.RegionCentroid);
% 	oArea{m} = gather(obj.RegionArea);
% 	bt.updatetoc = toc(bt.updatetic);
%
% 	% 	end
% 	% 	oldmax = proc.sc.Max;
%
%
% 	% REPORT
% 	tms = 1000.*[bt.loadtoc, bt.proctoc, bt.savetoc, bt.updatetoc]./numFrames;
% 	fprintf('IDX: %d-%d ~~~~~~~~~~~~~\n\t',idx(1),idx(end));
% 	fprintf('Load: %3.3gms\tProcess: %3.3gms\tSave: %3.3gms\tUpdate: %3.3gms\t\n',tms(1),tms(2),tms(3),tms(4));
%
% 	imrc(obj.PrimaryRegionIdxMap)
% 	disp(obj.NumRegisteredRegions)
% 	drawnow
%



% end


% imsc(obj.LabeledRegionPixelStatistics.MeanArea)
%  imsc(obj.LabeledRegionPixelStatistics.EnSeedability - stat.EnSeedability)
%  stat = obj.LabeledRegionPixelStatistics;

%%
% mot = unifyStructArray(motionInfo);


%%
%
cellfun(@release, allSystems)
%
% if false
cellfun(@delete, allSystems)
cellfun(@delete, feedThroughSystem)
cellfun(@delete, otherSystem)
% 	dev = gpuDevice;
% 	dev.reset;
% end

% catch  me
% 	keyboard
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





catch me
	msg = getReport(me);
	disp(msg);
	%assignin('base','TL',TL)
	fprintf(['Assigned TL in base to call again without selecting new file\n',...
		'\n\te.g.\n\n\t\t>> runScicadelicVidGen(TL)\n\n']);
	keyboard
end

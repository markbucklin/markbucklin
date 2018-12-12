function [nextFcn, varargout] = getScicadelicPreProcessor(tiffLoader, saveBW,saveRGB)
% [nextFcn,pp] = getScicadelicPreProcessor(tiffLoader, saveBW,saveRGB);
% [nextFcn,pp] = getScicadelicPreProcessor(false,false);
% [nextFcn,pp] = getScicadelicPreProcessor([],false);
% [nextFcn,pp] = getScicadelicPreProcessor();
% nextFcn = getScicadelicPreProcessor();
%
%  [f,info,mstat,frgb,srgb] = nextFcn()

%%
framesPerStep = 8;
if nargin < 1
	tiffLoader = []
end
if nargin < 2
	saveBW = [];
end
if nargin < 3
	saveRGB = true;
end
if isempty(saveBW)
	saveBW = true;
end

%%
pp = struct('env',[],'sys',[],'fcn',[]);

% INITIALIZE GPU
pp.env.dev = gpuDevice;
reset(pp.env.dev);
parallel.gpu.rng(7301986,'Philox4x32-10');

% INITIALIZE THREAD POOL
pp.env.pool = gcp;


%% Tiff Loader
% if isempty(tiffLoader)
% 	TL = scicadelic.TiffStackLoader;
% 	TL.FramesPerStep = framesPerStep;
% 	TL.FrameInfoOutputPort = true;
% 	setup(TL)
% else
% 	% Use Tiff Loader from First Argument (Recycleable)
% 	if tiffLoader.isLocked()
% 		reset(tiffLoader);
% 	else
% 		tiffLoader.FramesPerStep = framesPerStep;
% 		setup(tiffLoader)
% 	end
% 	TL = tiffLoader;
% end

if isempty(tiffLoader)
	TL = scicadelic.TiffStackLoader;
else
	% Use Tiff Loader from First Argument (Recycleable)
	if tiffLoader.isLocked()
		release(tiffLoader);
	end
	reset(tiffLoader);
	TL = tiffLoader;
end
TL.FramesPerStep = framesPerStep;
TL.FrameInfoOutputPort = true;
try
setup(TL)
catch me
end

pp.env.numVideoFrames = TL.NumFrames;
assignin('base','TL',TL);


%% Generate Default Dataset Name & Export Path from Tiff Files
try
	videoFile = scicadelic.FileWrapper('FileName',TL.FileName, 'FileDirectory', TL.FileDirectory);
	pp.env.defaultDataSetName = videoFile.DataSetName;
catch
	pp.env.defaultDataSetName = TL.DataSetName;
end
pp.env.defaultExportPath = [TL.FileDirectory, 'export'];
if ~isdir(pp.env.defaultExportPath)
	mkdir(pp.env.defaultExportPath)
end
dateStamp = datestr(now,'(yyyymmmdd_HHMMPM)');
pp.env.videoFileNameRoot = [pp.env.defaultExportPath,filesep, pp.env.defaultDataSetName, dateStamp];


%% PROCESSING SYSTEMS
pp.sys.tiffloader = TL;
pp.sys.medianfilter = scicadelic.HybridMedianFilter;
pp.sys.contrastenhancer = scicadelic.LocalContrastEnhancer;
pp.sys.contrastenhancer.LpFilterSigma = 15; %7
pp.sys.contrastenhancer.UseInteractive = true;
pp.sys.motioncorrector = scicadelic.MotionCorrector;
pp.sys.temporalgradientstatisticcollector = scicadelic.TemporalGradientStatisticCollector;
pp.sys.temporalgradientstatisticcollector.DifferentialMomentOutputPort = true;
pp.sys.temporalgradientstatisticcollector.GradientRestriction = 'Positive Only'; %'Absolute Value';
pp.sys.temporalfilter = scicadelic.TemporalFilter;
pp.sys.temporalfilter.MinTimeConstantNumFrames = 6;% new
pp.sys.pixelintensitystatisticcollector = scicadelic.StatisticCollector('DifferentialMomentOutputPort',true);
pp.sys.temporalgradienttemporalfilter = scicadelic.TemporalFilter('MinTimeConstantNumFrames',6);


%% OUTPUT EXTRACTORS (IMAGE NORMALIZERS)
gmcRstat = []; gmcBstat = [];
INg = scicadelic.ImageNormalizer('NormalizationType','ExpNormComplement');
% INb = scicadelic.ImageNormalizer('NormalizationType','Geman-McClure');
% INr = scicadelic.ImageNormalizer('NormalizationType','Geman-McClure');
MF = pp.sys.medianfilter;


%% PROCEDURE ORDER
feedThroughSystem = {...
	pp.sys.medianfilter
	pp.sys.contrastenhancer
	pp.sys.motioncorrector
	pp.sys.temporalfilter
	pp.sys.temporalgradienttemporalfilter
	};
otherSystem = {...
	pp.sys.temporalgradientstatisticcollector
	pp.sys.pixelintensitystatisticcollector
	INg
	% 	INr
	% 	INb
	};
allSystems = cat(1,{TL},feedThroughSystem,otherSystem);

%% PREALLOCATE VARIABLES & DATA-OUTPUT ARRAYS

% SIZE/DIMENSION
pp.env.numRows = TL.FrameSize(1);
pp.env.numCols = TL.FrameSize(2);
N = TL.numFrames;
pp.env.numFrames = N;

%% INITIALIZE COUNTERS & SHARED DATA VARIABLES
idx = 0;
m = 0;
stopIdx = N;
F = [];
frameTime = [];
idx = 0;
dstat = struct.empty();
gdstat = struct.empty();
finishedFlag = false;
numChunks = ceil(N/framesPerStep);
chunkInfo = struct(...
	'idx',cell(1,numChunks),...
	'timestamp',cell(1,numChunks),...
	'motion',cell(1,numChunks));

%% RUN CHUNKS IN LOOP
s0 = [];
sa = [];

%%

pp.fcn.next = @next;
pp.fcn.processchunk = @processChunk;
pp.fcn.updatestats = @updatePixelStatistics;
pp.fcn.generatergb = @generateColorCodedMarginalStatChannels;
pp.fcn.savergbmarginalstatsfile = @saveRGBMarginalStatFile;
pp.fcn.savebwrawintensityfile = @saveBWRawIntensityFile;
pp.fcn.checkfinished = @checkFinishedFlag;
pp.fcn.release = @releaseAndDeleteSystems;
pp.fcn.updatepp = @updateWorkspacePPStruct;

nextFcn = @next;

if nargout > 1
	varargout{1} = pp;
end

%%
%

% processChunk()% (idx)

% updatePixelStatistics()

%% TRANSFER/EXTRACT/SAVE/OUTPUT DATA
% RAW DATA OUTPUT (FLUORESCENCE-INTENSITY & MOTION)
% 	Fcpu(:,:,idx) = gather(F);

%% RGB
% fRGB = generateColorCodedMarginalStatChannels()
% saveRGB(fRGB)


%     function runChunks(n)
%
%     end
	function [f,info,mstat,frgb,srgb] = next()
		if ~finishedFlag
			[f,info] = processChunk();
			mstat = updatePixelStatistics();
			[srgb,frgb] = generateColorCodedMarginalStatChannels();
			if saveRGB
				saveRGBMarginalStatFile(frgb);
			end
			if saveBW
				saveBWRawIntensityFile(f);
			end
		else
			if strcmp(questdlg('Release and delete all systems?'),'Yes')
				releaseAndDeleteSystems();
			else
				% todo
				try
					% Restart (new)
					idx = 0;
					m = 0;
					finishedFlag = false;
					[f,info,mstat,frgb,srgb] = next();
				catch
					f = [];
					info = [];
					mstat = [];
					frgb = [];
					srgb = [];
				end
			end
		end
	end
	function varargout = processChunk()
		if isempty(idx) || (idx(end) >= stopIdx)
			return
		end
		m=m+1;
		
		% LOAD ------------------------------------
		if isDone(TL) || (idx(end) >= stopIdx)
			F = [];
			idx = [];
			frameTime = [];
			finishedFlag = true;
			return
		else
			[frameData, frameInfo, frameIdx] = step(TL);
			frameTime = frameInfo.t;
			
		end
		
		F = single(squeeze(gpuArray(frameData)));
		idx = frameIdx;
		
		% PROCESS ------------------------------------
		% HYBRID MEDIAN FILTER ON GPU
		F = step(pp.sys.medianfilter, F);
		
		% CONTRAST ENHANCEMENT
		F = step(pp.sys.contrastenhancer, F);
		
		% MOTION CORRECTION
		[F,motionInfo] = step( pp.sys.motioncorrector, F);
		
		% TEMPORAL SMOOTHING (ADAPTIVE)
		F = step(pp.sys.temporalfilter, F);
		
		% Info
		chunkInfo(m).idx = frameIdx(:);
		chunkInfo(m).timestamp = frameTime(:);
		chunkInfo(m).motion = motionInfo;
		
		if nargout
			varargout{1} = F; % changed (was gather(F))
			if nargout > 1
				varargout{2} = chunkInfo(m);
			end
		end
		
		
	end
	function varargout = updatePixelStatistics()
		% TEMPORAL GRADIENT STATISTSTICS
		gdstat = step(pp.sys.temporalgradientstatisticcollector, F, frameTime);
		
		% STATISTIC COLLECTION
		dstat = step(pp.sys.pixelintensitystatisticcollector, F);
		
		if nargout
			varargout{1} = struct('marginalintensity',dstat,'marginalintensitychange',gdstat);
		end
	end
	function fin = checkFinishedFlag()
		fin = logical(finishedFlag);
	end

% RGB DATA OUTPUT
	function [sRGB, fRGB] = generateColorCodedMarginalStatChannels()
		
		numFrames = numel(idx);
		sRGB = [];
		fRGB = [];
		
		try
			%% TRY OLD WAY (NO BACKGROUND)
			
			% RED
			fRed = dstat.M4;
			fRed = step(MF, fRed);
			[fRed, gmcRstat] = gemanMcClureNormalizationRunGpuKernel(fRed, gmcRstat);			% 	fR = step(INr, fR);
			
			% NEW TEMPORAL FILTER
			fRed = step( pp.sys.temporalgradienttemporalfilter, fRed);
			
			% GREEN
			fGreen = F;
			fGreen = step(INg, fGreen);
			
			% BLUE
			fBlue = gdstat.M3;
			fBlue = step(MF, fBlue);
			[fBlue, gmcBstat] = gemanMcClureNormalizationRunGpuKernel(fBlue, gmcBstat); % 	fB = step(INb, fB);
			
			
			%% New - Always build structure sRGB
			sRGB = struct(...
				'marginalKurtosisOfIntensity',fRed,...
				'marginalSkewnessOfIntensityChange',fBlue,...
				'inverseIntensityNormalizedToHistoricalMax',fGreen);
			
			%% RGB - COMPOSITE (UINT8)
			if nargout > 1
				if idx(1) > 4
					fRGB = cat(3, ...
						uint8(reshape(fRed.*255, pp.env.numRows, pp.env.numCols, 1, numFrames)) ,...
						uint8(reshape(fGreen.*255, pp.env.numRows, pp.env.numCols, 1, numFrames)) ,...
						uint8(reshape(fBlue.*255, pp.env.numRows, pp.env.numCols, 1, numFrames)));
				else
					% Blank frames if not enough frames for valid stats yet
					fRGB = gpuArray.zeros(pp.env.numRows,pp.env.numCols,3,numFrames,'uint8');
					
				end
			end
			
		catch me
			getReport(me)
			%%
			% 			if idx(1) > 4
			% 				% RGB DATA OUTPUT (DIFFERENTIAL MOMENTS)
			% 				fBlue = dstat.M4;
			% 				fBlue = step(MF, fBlue);
			% 				[fBlue, gmcRstat] = gemanMcClureNormalizationRunGpuKernel(fBlue, gmcRstat);
			% 				fGreen = F;
			% 				fGreen = step(INg, fGreen);
			% 				fRed = gdstat.M3;
			% 				fRed = step(MF, fRed);
			% 				[fRed, gmcBstat] = gemanMcClureNormalizationRunGpuKernel(fRed, gmcBstat); % if < 512 use fB/max(fB)??
			%
			%
			% 				% NEW TEMPORAL FILTER
			% 				fRed = step( pp.sys.temporalgradienttemporalfilter, fRed);
			%
			% 				a = .90;
			% 				if isempty(s0)
			% 					s0 = mean(min(F,[],1),2);
			% 					sa = mean(range(F,1),2);
			% 				else
			% 					s0 = s0(1:numFrames);
			% 					sa = sa(1:numFrames);
			% 					s0new = mean(min(F,[],1),2);
			% 					sanew = mean(range(F,1),2);
			% 					ks=1;
			% 					s0(ks) = a*s0(end) + (1-a)*s0new(ks);
			% 					sa(ks) = a*sa(end) + (1-a)*sanew(ks);
			% 					while (ks < numFrames)
			% 						ks = ks + 1;
			% 						s0(ks) = a*s0(ks-1) + (1-a)*s0new(ks);
			% 						sa(ks) = a*sa(ks-1) + (1-a)*sanew(ks);
			% 					end
			% 				end
			%
			% 				fBase = bsxfun( @times, (1./sa) , bsxfun(@minus, F , s0));
			% 				% 		fBase = fBase.*(0.3 + (0.3*fRed + 0.2*fGreen + 0.2*fBlue));% new
			%
			% 				nanPix = isnan(fRed(:));
			% 				if any(nanPix), fRed(nanPix) = 0; end
			% 				nanPix = isnan(fGreen(:));
			% 				if any(nanPix), fGreen(nanPix) = 0; end
			% 				nanPix = isnan(fBlue(:));
			% 				if any(nanPix), fBlue(nanPix) = 0; end
			%
			% 				% fRed = fRed .* (0.5 .* (1 + fBase))
			% 				% fBlue = fBlue .* (0.5 .* (1 + fBase))
			%
			% 				fBlue = max( fBlue-fRed, 0);%nextrun % or fBlue = fBlue .* (1-fRed);
			% 				rbc = single(0.3);
			% 				% 		fBase = (fBase .* ( 1 - bsxfun(@max, fRed, fBlue)));
			% 				%NEXT% fGreen = fGreen .* 0.5*( 1 + fBase);
			%
			% 				fRGB = bsxfun(@plus, ...
			% 					uint8(reshape( fBase.*255.*rbc, pp.env.numRows,pp.env.numCols,1,numFrames)), ...
			% 					cat(3, ...
			% 					uint8(reshape( fRed.*255, pp.env.numRows, pp.env.numCols, 1, numFrames)) ,...
			% 					uint8(reshape( fGreen.*255.*(1-rbc), pp.env.numRows, pp.env.numCols, 1, numFrames)) ,...
			% 					uint8(reshape( fBlue.*255, pp.env.numRows, pp.env.numCols, 1, numFrames))) );
			%
			% 			else
			% 				% Blank frames if not enough frames for valid stats yet
			% 				fRGB = gpuArray.zeros(pp.env.numRows,pp.env.numCols,3,numFrames,'uint8'); % added gpuArray.zeros
			%
			% 			end
		end
		% 		if nargout > 1
		
		% 			varargout{1} = struct(...
		% 				'marginalKurtosisOfIntensity',fRed,...
		% 				'marginalSkewnessOfIntensityChange',fBlue,...
		% 				'inverseIntensityNormalizedToHistoricalMax',fGreen);
		% 		end
	end
	function saveRGBMarginalStatFile(varargin)
		if nargin
			fRGB = oncpu(varargin{1});
		else
			[~, fRGB] = generateColorCodedMarginalStatChannels();
		end
		% WRITE to Raw BINARY FILE
		rgbBinaryFileNameRoot = [pp.env.videoFileNameRoot, ' [RGB]'];
		pp.env.rgbfilename = writeBinaryData(fRGB, rgbBinaryFileNameRoot, false);
		
		
	end
	function saveBWRawIntensityFile(varargin)
		if nargin
			fBW = oncpu(varargin{1});
		else
			fBW = oncpu(F);
		end
		% WRITE to Raw BINARY FILE
		bwBinaryFileNameRoot = [pp.env.videoFileNameRoot, ' [BW-Intensity]'];
		pp.env.bwfilename = writeBinaryData(fBW, bwBinaryFileNameRoot, false);
		
	end
	function releaseAndDeleteSystems()
		cellfun(@release, allSystems)
		cellfun(@delete, allSystems)
		cellfun(@delete, feedThroughSystem)
		cellfun(@delete, otherSystem)
	end
	function updateWorkspacePPStruct()
		ppVarIsInBaseWS = evalin('base','exist(''pp'',''var'')');
		if ppVarIsInBaseWS
			assignin('base','pp',pp)
		end
	end

end

function runScicadelicVidGenWithBehavior(TL)


%%
dev = gpuDevice;
reset(dev);
parallel.gpu.rng(7301986,'Philox4x32-10');

if isempty(gcp('nocreate'))
	parpool(12)
end

if (nargin<1)
	TL = scicadelic.TiffStackLoader;
	TL.FrameInfoOutputPort = true;
	setup(TL)
else
	reset(TL)
end
numVideoFrames = TL.NumFrames;


% GET MOVEMENT DATA
[movementDataFile, movementDir] = uigetfile('*.mat','Choose a Movement-Data File');
movementData = load(fullfile(movementDir,movementDataFile));
numMovementFrames = length(movementData.info.FrameNumber);

S.left.x = reshape( movementData.data(1,1,:), [], 1);
S.left.y = reshape( movementData.data(1,2,:), [], 1);
S.right.x = reshape( movementData.data(1,3,:), [], 1);
S.right.y = reshape( movementData.data(1,4,:), [], 1);
S.left.x(2) = 0;
S.left.y(2) = 0;
S.right.x(2) = 0;
S.right.y(2) = 0;

temporaryScaleFactor = 1 * 1/median(abs(diff(S.left.y)));
S.left.x = S.left.x*temporaryScaleFactor;
S.left.y = S.left.y*temporaryScaleFactor;
S.right.x = S.right.x*temporaryScaleFactor;
S.right.y = S.right.y*temporaryScaleFactor;


S.left.xrotvec = [0 0 1];
S.left.yrotvec = 1/sqrt(2) .* [1 -1 0];
S.right.xrotvec = [0 0 1];
S.right.yrotvec = 1/sqrt(2) .* [1 1 0];


% INITIALIZE GRAPHICS HANDLES
h.fig = [];


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
mp4FileName = [defaultExportPath,filesep, defaultDataSetName, dateStamp, '.mp4'];



% MP4 COMPRESSION & FRAMERATE SETTINGS
% fpsMultiplier = 2;
% Tduration = TL.LastFrameTime - TL.FirstFrameTime ;
% FPSmp4 = fpsMultiplier * TL.StackInfo.numFrames/ Tduration;
FPSmp4 = 25;
FPSdescription = '1X (Approximate)';
profile = 'MPEG-4';
writerObj = VideoWriter(mp4FileName,profile);
writerObj.FrameRate = FPSmp4;
writerObj.Quality = 95;
addlistener(writerObj, 'ObjectBeingDestroyed', @(src,evnt)close(src) );
open(writerObj)
% (remember to)
% writeVideo(writerObj, F)


%% PROCESSING SYSTEMS
proc.mf = scicadelic.HybridMedianFilter;
proc.ce = scicadelic.LocalContrastEnhancer;
proc.ce.LpFilterSigma = 7;
proc.ce.UseInteractive = true;
proc.mc = scicadelic.MotionCorrector;
proc.tgsc = scicadelic.TemporalGradientStatisticCollector;
proc.tgsc.DifferentialMomentOutputPort = true;
proc.tgsc.GradientRestriction = 'Positive Only'; %'Absolute Value';
proc.tf = scicadelic.TemporalFilter;
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
N = min( numVideoFrames, numMovementFrames);
numFrames = TL.FramesPerStep;
numSteps = ceil(N/numFrames);

nidx = 0;
bw = [];
bwl = [];
dm=0;
didx = 0;

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
		
		% ------------------------------------
		% LOAD
		% ------------------------------------
		bt.loadtic = tic;
		% 	[F, idx] = TL.step();
		
		if isDone(TL)
			break
		else
			% 			[frameData, frameIdx] = step(TL);
			[frameData, frameInfo, frameIdx] = step(TL);
			frameTime = frameInfo.t;
			
		end
		
		F = single(squeeze(gpuArray(frameData)));
		idx = frameIdx;
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
		gdstat = step(proc.tgsc, F, frameTime);
		
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
		
		% ------------------------------------
		% PUT FRAMES IN VIDEO FRAME
		% ------------------------------------		
		if isempty(h.fig)
			h = initBehavSyncVideo(fRGB, S);
		end
		
		sphereRadius = 10; % ksphere below -> todo
		kRot = 1;
		while (kRot <= numel(idx))
			drawnow
			rotIdx = idx(kRot);
			% ROTATE SPHERE
			rotate(h.surf, S.left.xrotvec, S.left.x(rotIdx))
			rotate(h.surf, S.right.xrotvec, S.right.x(rotIdx))
			rotate(h.surf, S.left.yrotvec, S.left.y(rotIdx))
			rotate(h.surf, S.right.yrotvec, S.right.y(rotIdx))
			% M = makehgtform('axisrotate',S.left.xrotvec,S.left.x(rotIdx))
			% 			Mxa = makehgtform('axisrotate', S.left.xrotvec, S.left.x(rotIdx));
			% 			Mxb = makehgtform('axisrotate', S.right.xrotvec, S.right.x(rotIdx));
			% 			Mya = makehgtform('axisrotate', S.left.yrotvec, S.left.y(rotIdx));
			% 			Myb = makehgtform('axisrotate', S.right.yrotvec, S.right.y(rotIdx));
			% 			h.trans.Matrix = Mxa * Mxb * Mya * Myb;% ??
			drawnow
			
			% ADD COLOR TO MOUSE-POSITION (WHILE FADING HISTORICAL TRACES)
			XYZ = cat(3, abs(h.surf.XData), abs(h.surf.YData), 1-h.surf.ZData);
			northPole = repmat(all(bsxfun(@lt, XYZ, reshape([.05 .05 .3], 1, 1, 3)), 3),1,1,3);
			numPix = nnz(northPole)/3;
			h.surf.CData(northPole) = h.surf.CData(northPole)...
				+ uint8(single(h.surf.CData(northPole))...
				.* [-ones(numPix*2,1,'single');ones(numPix,1,'single')] .* 0.25) ;
			
			% UPDATE VIDEO FRAME
			
			% INCREMENT
			kRot = kRot + 1;
	
			% GET FRAME
		end
		
		
		
		
		
		
		
		% ------------------------------------
		% SEND RGB FRAMES TO MP4 VIDEO WRITER
		% ------------------------------------
		writeVideo(writerObj, fRGB)
		
		% BENCHMARK-TIME
		bt.savetoc = toc(bt.savetic);
		
	catch me
		msg = getReport(me);
		disp(msg)
		break
	end
end

cellfun(@release, allSystems)
%
% if false
cellfun(@delete, allSystems)
cellfun(@delete, feedThroughSystem)
cellfun(@delete, otherSystem)








	function h = initBehavSyncVideo(fRGB, S)
		h.fig = figure;
		ksphere = 8;
		nsphere = 2^ksphere-1;
		theta = pi*(-nsphere:2:nsphere)/nsphere;
		phi = (pi/2)*(-nsphere:2:nsphere)'/nsphere;
		X = cos(phi)*cos(theta);
		Y = cos(phi)*sin(theta);
		Z = sin(phi)*ones(size(theta));
		% 		colormap([0 0 0;1 1 1])
		% 		C = hadamard(2^ksphere);
		
		C = repmat( uint8(100 + 50*rand([2^ksphere, 2^ksphere, 1])), [1 1 3]);
		
		h.sphereax = gca;
		h.trans = hgtransform('Parent',h.sphereax);		
		h.surf = surface(X,Y,Z,C,'Parent',h.trans);
		setAutoProps2Manual(h.sphereax); %ignition.util.setAutoProps2Manual
		
		% SURFACE PROPS
		set(h.surf,...
			'EdgeColor','none',...
			'EdgeLighting','none',...			
			'FaceLighting','flat',...
			'FaceColor','interp',...
			'AlphaDataMapping','direct',...
			'DiffuseStrength', 0.1,...
			'SpecularStrength',0.3,...
			'MeshStyle','row',...
			'EdgeAlpha',0.15)
		
		% AXES PROPS
		viewElev = 60;
		set(h.sphereax,...
			'Visible','off' ,...
			'View', [ 0 viewElev])
		
		
		% LIGHTS
		h.light(1) = light('Parent',h.sphereax,...
			'Position', [-ksphere -ksphere 0],...
			'Color', [1 .2 .2],...
			'Style','local');
		h.light(2) = light('Parent',h.sphereax,...
			'Position', [ksphere -ksphere 0],...
			'Color', [1 .2 .2],...
			'Style','local')
		
		h.light(3) = light('Parent',h.sphereax,'Position', [0 0 ksphere*2],'Style','infinite')
		
		set(h.fig,...
			'Color', [0.5 0.5 0.5])
		
		
		% VIDEO (IMAGE) AXES
		% todo
		
		
		
	end





end











% DELETE LIGHTS
% 		delete(findobj(get(gca,'Children'),'type','light'))








% 		fBase = bsxfun(@plus, F, (.4*fBlue + .6*fRed) );

% 		if isempty(s0)
% 			s0 = mean(mean(min(F,[],1),2));
% 			sa = mean(mean(range(F,1),2));
% 		else
% 			s0 = a*s0 + (1-a)*mean(mean(min(F,[],1),2));
% 			sa = a*sa + (1-a)*mean(mean(range(F,1),2));
% 		end



% 		fRGB = gather( cat(3, ...
% 			uint8(reshape(fR.*255, numRows, numCols, 1, numFrames)) ,...
% 			uint8(reshape(fG.*255, numRows, numCols, 1, numFrames)) ,...
% 			uint8(reshape(fB.*255, numRows, numCols, 1, numFrames))) );




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



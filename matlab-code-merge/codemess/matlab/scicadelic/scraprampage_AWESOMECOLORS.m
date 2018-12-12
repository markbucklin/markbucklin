


% proc = initProc();
dev = gpuDevice;
% for k=1:20, F = step(proc.mc, step(proc.ce, step(proc.mf, step(proc.tl)))); wait(dev), dstat = step(obj,F); wait(dev), dstatcpu(k) = oncpu(dstat); disp(k), end



%% INITIALIZE
if ~exist('proc','var')
	proc = initProc;
else
	proc = initProc(proc.tl);
end

release(proc.tl);
proc.tl.FramesPerStep = 8;
setup(proc.tl)
reset(proc.tl);


%%
proc.tf.AutoRegressiveCoefficients = .6;
proc.tf.AutoRegressiveOrder = 2;

tfn0 = 2;
% TF2 = scicadelic.TemporalFilter;
% TF2.AutoRegressiveCoefficients = exp(-1/tfn0);
% TF2.AutoRegressiveOrder = 1;

TFr = scicadelic.TemporalFilter;
TFr.AutoRegressiveCoefficients = exp(-1/tfn0);
TFr.AutoRegressiveOrder = 1;

TFb = scicadelic.TemporalFilter;
TFb.AutoRegressiveCoefficients = exp(-1/tfn0);
TFb.AutoRegressiveOrder = 1;


INg_expcomp = scicadelic.ImageNormalizer;
INg_expcomp.NormalizationType = 'ExpNormComplement';
INg = scicadelic.ImageNormalizer;

INr_geman = scicadelic.ImageNormalizer;
INr_geman.NormalizationType = 'Geman-McClure';
% INr = scicadelic.ImageNormalizer;

INb_geman = scicadelic.ImageNormalizer;
INb_geman.NormalizationType = 'Geman-McClure';
% INb = scicadelic.ImageNormalizer;

tfgso = scicadelic.TemporalGradientStatisticCollector;
tfgso.DifferentialMomentOutputPort = true;

% N = 512;

MF = scicadelic.HybridMedianFilter;





%%
% Fsample = getDataSample(proc.tl, N);
% [numRows,numCols,~] = size(Fsample);
numRows = proc.tl.FrameSize(1);
numCols = proc.tl.FrameSize(2);
N = proc.tl.NumFrames;

% N = N;

%%
% Fcpu(numRows,numCols,N) = uint16(0);

% Fexpcpu(numRows,numCols,N) = uint16(0);
% Ftcpu(numRows,numCols,N) = uint8(0);
% Rcpu(numRows,numCols,N) = int8(0);
dMotMag(N,1) = single(0);
% dm1(numRows,numCols,N) = uint8(0);
% dm2(numRows,numCols,N) = uint8(0);
% dm3(numRows,numCols,N) = uint8(0);
% dm4(numRows,numCols,N) = uint16(0);

% gdm2(numRows,numCols,N) = single(0);
% gdm4(numRows,numCols,N) = uint16(0);

Frgb(numRows,numCols,3,N) = uint8(0);


%% BURN IN
% [sdata, sinfo] = getDataSample(TL);
if proc.tl.isLocked
	reset(proc.tl)
	idx = 0;
end

%%

preBreak = N;


%%
while ~isempty(idx) && (idx(end) < N)
	[F, mot, dstat, proc] = feedFrameChunk(proc);
	% 	Fsmooth = gaussFiltFrameStack(F, 1);
	% 	[R,Rmean,Rvar] = computeLayerFromRegionalComparisonRunGpuKernel(F, [], [], Fsmooth);
	% 	Rsmooth = gaussFiltFrameStack(R, 1);
	idx = oncpu(proc.idx(proc.idx <=N));
	% 	F0 = step(TF0, F);
	% 	Ft = single(F)-single(F0);
	
	gdstat = step(tfgso, F);
	
% 	Fcpu(:,:,idx) = gather(F);
	% 	Ftcpu(:,:,idx) = gather(uint8(256*expnorm(Ft)));
	% 	Rcpu(:,:,idx) = gather(int8(128*Rsmooth));
	
	% 	gdm2(:,:,idx) = gather(step(TF2, gdstat.M2));
	
	
	numFrames = numel(idx);
	
	fR = dstat.M4;
	fR = step(MF, fR);
	fR = step(TFr, fR);
	fR = step(INr_geman, fR);
	% 	fR = step(INr, fR);
	% 	gdm4(:,:,idx) = gather(uint16(65535.* fR));
	
	fG = F;
	fG = step(INg_expcomp, fG);
	fG = step(INg, fG);
	% 	Fexpcpu(:,:,idx) = gather(uint16(65535.* fG));
	
	fB = sqrt(abs(gdstat.M4));
	fB = step(MF, fB);
	fB = step(TFb, fB);
	fB = step(INb_geman, fB);
	dm4(:,:,idx) = gather(uint16(65535.* fB));
% 	fB = gpuArray.zeros(numRows,numCols,1,numFrames, 'uint8');
	
	
	fRGB = cat(3,...
		uint8(reshape(fR.*255, numRows, numCols, 1, numFrames)) ,...
		uint8(reshape(fG.*255, numRows, numCols, 1, numFrames)) ,...
		uint8(reshape(fB.*255, numRows, numCols, 1, numFrames)));
	
	Frgb(:,:,:,idx) = gather(fRGB);
	
	
	
	
	% 	dm4(:,:,idx) = gather(step(TF0, dstat.M4));
	dMotMag(idx) = gather(mot.dmag);
	% 	dm1(:,:,idx) = gather(uint8(256*expnorm(dstat.M1)));
	% 	dm2(:,:,idx) = gather(uint8(256*expnorm(realsqrt(dstat.M2))));
	% 	dm3(:,:,idx) = gather(uint8(256*expnorm(sslog(dstat.M3))));
	% 	dm4(:,:,idx) = gather(uint8(256*expnorm(sslog(dstat.M4))));
	wait(dev)
	
	if idx(end)>=preBreak
		break
	end
	
end



%% AWESOME DISPLAY

% Frgb = bsxfun(@bitand, Frgb, uint8(cat(3,255,255,0)));


% Frgb = cat(3,...
% reshape(uint8(dm4./256), numRows,numCols,1,[]),...
% reshape(uint8((Fexpcpu-1024)./256), numRows,numCols,1,[]),...
% 	zeros(numRows,numCols,1,N,'uint8'));

% imrgbplay(...
% 	cat(3,...
% 	reshape(uint16(65535.*expnorm(gdm4(:,:,48:end))),1024,1024,1,[]),...
% 	reshape(uint16(65535.*expnorm(expnormalizedcomplement(Fcpu(:,:,48:end)))),1024,1024,1,[]),...
% 	reshape(uint16(65535.*expnorm(dm4(:,:,48:end))),1024,1024,1,[])));

% s = getappdata(h.fig,'s');
% [expName,~] = strtok(proc.tl.FileName{1},'.')
% rgbName = sprintf('RGB (dM4Ft-expcompF-dM4F) - %s',expName);
% saveData2Mp4(s.f, rgbName)

% NOTE:
%			-> RED indicates that pixel intensity is CHANGING faster than normal
%							(differential 4th central moment of temporal derivative of F)
%			-> GREEN is the 'expnormalizedcomplement' of F, decreases as pixel intensity approaches its max value
%			-> BLUE indicates that pixel intensity is well outside of it's NORMAL intensity range
%							(differential 4th central moment of pixel intensity, F)
















%%
% clearvars f
% release(INb)
% release(INg)
% release(INr)
% release(INf)
% release(TF4)
% release(tfgso)
% proc = dismissProc(proc);


%%
% proc = initProc(proc.tl);
% clc
%
%
% %%
% proc.tf.AutoRegressiveCoefficients = .6;
% proc.tf.AutoRegressiveOrder = 2;
%
% %%
% tfn0 = 2;
% TF4 = scicadelic.TemporalFilter;
% TF4.AutoRegressiveCoefficients = exp(-1/tfn0);
% TF4.AutoRegressiveOrder = 1;
% INf = scicadelic.ImageNormalizer;
% INf.NormalizationType = 'ExpNormComplement';
% INr = scicadelic.ImageNormalizer;
% INg = scicadelic.ImageNormalizer;
% INb = scicadelic.ImageNormalizer;
% tfgso = scicadelic.TemporalGradientStatisticCollector;
% tfgso.DifferentialMomentOutputPort = true;
%









